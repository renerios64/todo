# Main entrypoint for the dev environment.
# Resources are added here as we build out each layer.

locals {
  # Consistent name prefix reused across all resources: todo-dev
  name_prefix = "${var.project}-${var.environment}"
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name_prefix}-${var.location}"
  location = var.location
}

# Separate resource group for Key Vault — intentionally isolated so that
# destroying the main resource group never deletes secrets.
resource "azurerm_resource_group" "secrets" {
  name     = "rg-secrets-${local.name_prefix}-${var.location}"
  location = var.location
}

# ── Networking ────────────────────────────────────────────────────────────────

resource "azurerm_virtual_network" "main" {
  name                = "vnet-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.0.0/16"]
}

# Container Apps Environment requires a dedicated subnet of at least /23 (512 IPs).
# Azure injects ACA infrastructure IPs directly into this subnet.
resource "azurerm_subnet" "container_apps" {
  name                 = "snet-aca-${local.name_prefix}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.0.0/23"]

  delegation {
    name = "aca-delegation"
    service_delegation {
      name = "Microsoft.App/environments"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

# PostgreSQL Flexible Server requires a delegated /24 subnet for private access.
# Azure places the Postgres network interface directly inside the VNet.
resource "azurerm_subnet" "postgres" {
  name                 = "snet-psql-${local.name_prefix}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]

  delegation {
    name = "psql-delegation"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

# ── Private DNS ───────────────────────────────────────────────────────────────

# Azure PostgreSQL Flexible Server (with private/delegated subnet access) requires
# this exact zone name — it auto-registers its hostname here on creation.
resource "azurerm_private_dns_zone" "postgres" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.main.name
}

# Link the DNS zone to our VNet so resources inside the VNet can resolve it.
# registration_enabled = false means Postgres auto-registers its own A record.
resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "vnetlink-psql-${local.name_prefix}"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
}

# ── Container Registry ────────────────────────────────────────────────────────

# ACR name must be globally unique and alphanumeric only (no hyphens).
# substr(..., 0, 6) takes the first 6 chars of the subscription ID as a
# unique suffix — short enough to keep the name under 50 chars.
locals {
  acr_name = "acr${replace(local.name_prefix, "-", "")}${substr(var.subscription_id, 0, 6)}"
}

resource "azurerm_container_registry" "main" {
  name                = local.acr_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = true
}

output "acr_login_server" {
  value = azurerm_container_registry.main.login_server
}

# ── PostgreSQL Flexible Server ────────────────────────────────────────────────

resource "azurerm_postgresql_flexible_server" "main" {
  name                = "psql-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  # Burstable B1ms: 1 vCPU, 2 GB RAM — cheapest option, fine for dev
  sku_name = "B_Standard_B1ms"
  version  = "16"
  zone     = "3"  # Pin to the zone Azure auto-assigned at creation

  # Private access via delegated subnet — no public IP assigned
  delegated_subnet_id           = azurerm_subnet.postgres.id
  private_dns_zone_id           = azurerm_private_dns_zone.postgres.id
  public_network_access_enabled = false

  administrator_login    = "todoadmin"
  administrator_password = data.azurerm_key_vault_secret.db_password.value

  storage_mb            = 32768  # 32 GB minimum
  backup_retention_days = 7

  # Postgres must wait for the DNS zone VNet link to exist,
  # otherwise it can't register its private hostname.
  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres]
}

resource "azurerm_postgresql_flexible_server_database" "app" {
  name      = "todoapp"
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

output "db_host" {
  value = azurerm_postgresql_flexible_server.main.fqdn
}

# ── Key Vault ─────────────────────────────────────────────────────────────────

# User-Assigned Managed Identity — a reusable Azure identity attached to our
# container apps so they can authenticate to Key Vault without any credentials.
# "User-assigned" means it exists independently of any single resource and can
# be shared across multiple container apps.
resource "azurerm_user_assigned_identity" "main" {
  name                = "mi-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

locals {
  # Key Vault name: max 24 chars, alphanumeric + hyphens, globally unique.
  # We reuse the same 6-char subscription prefix pattern as ACR.
  kv_name = "kv-${local.name_prefix}-${substr(var.subscription_id, 0, 6)}"
}

resource "azurerm_key_vault" "main" {
  name                = local.kv_name
  resource_group_name = azurerm_resource_group.secrets.name
  location            = azurerm_resource_group.secrets.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  # Use Azure RBAC for access control instead of legacy access policies.
  # RBAC is the modern approach — permissions are managed as role assignments,
  # consistent with how all other Azure resources work.
  rbac_authorization_enabled = true

  # In dev, disable purge protection so we can destroy the vault immediately.
  # In prod, enable this to prevent accidental permanent deletion.
  purge_protection_enabled = false

  # Soft delete is always enabled in Azure (can't be disabled), but we set
  # retention to 7 days (minimum) so dev cleanup isn't blocked for 90 days.
  soft_delete_retention_days = 7
}

# Pull the current Terraform runner's client config (tenant ID, object ID).
# Used to grant the deployer access to write secrets into the vault.
data "azurerm_client_config" "current" {}

# Grant the deployer (you, running Terraform) permission to read/write secrets.
# Without this, Terraform can create the vault but can't write secrets into it.
resource "azurerm_role_assignment" "kv_deployer_secrets_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.deployer_object_id
}

# Grant the managed identity permission to READ secrets.
# Container apps use this identity at runtime to fetch secrets from Key Vault.
resource "azurerm_role_assignment" "kv_mi_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
}

# Store the full DB connection string in Key Vault.
# The local assembles it from the Postgres FQDN + the password read from Key Vault.
# Nothing sensitive lives in Terraform state or tfvars.
resource "azurerm_key_vault_secret" "db_connection_string" {
  name         = "db-connection-string"
  value        = local.db_connection_string
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.kv_deployer_secrets_officer]
}

# Store the ACR admin password in Key Vault.
resource "azurerm_key_vault_secret" "acr_password" {
  name         = "acr-admin-password"
  value        = azurerm_container_registry.main.admin_password
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_role_assignment.kv_deployer_secrets_officer]
}

output "key_vault_uri" {
  value = azurerm_key_vault.main.vault_uri
}

# Read the DB password back from Key Vault so it never needs to be passed
# on the command line or stored in tfvars. This data source runs at plan/apply
# time and fetches the current secret value directly from Key Vault.
data "azurerm_key_vault_secret" "db_password" {
  name         = "db-admin-password"
  key_vault_id = azurerm_key_vault.main.id

  # The Secrets Officer role assignment must exist before we can read secrets.
  depends_on = [azurerm_role_assignment.kv_deployer_secrets_officer]
}



# Log Analytics is required by Container Apps Environment for log ingestion.
resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"  # Pay-per-GB — cheapest option
  retention_in_days   = 30
}

resource "azurerm_container_app_environment" "main" {
  name                       = "cae-${local.name_prefix}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  # VNet integration — place the environment inside our ACA subnet.
  # This allows container apps to reach Postgres via private IP.
  infrastructure_subnet_id = azurerm_subnet.container_apps.id

  # Azure auto-assigns these fields at creation time — ignore drift.
  lifecycle {
    ignore_changes = [
      infrastructure_resource_group_name,
      workload_profile,
    ]
  }
}

output "aca_environment_id" {
  value = azurerm_container_app_environment.main.id
}

# ── API Container App ─────────────────────────────────────────────────────────

locals {
  db_connection_string = "Host=${azurerm_postgresql_flexible_server.main.fqdn};Database=todoapp;Username=todoadmin;Password=${data.azurerm_key_vault_secret.db_password.value};SSL Mode=Require"
}

resource "azurerm_container_app" "api" {
  name                         = "ca-api-${local.name_prefix}"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  # Attach the managed identity so this app can authenticate to Key Vault
  # at runtime without any embedded credentials.
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.main.id]
  }

  # ACR credentials so the environment can pull our image
  registry {
    server               = azurerm_container_registry.main.login_server
    username             = azurerm_container_registry.main.admin_username
    password_secret_name = "acr-password"
  }

  # Secrets now reference Key Vault by versioned URL.
  # Azure Container Apps fetches the value directly from Key Vault at deploy time
  # — the plaintext never appears in Terraform state.
  secret {
    name                = "acr-password"
    key_vault_secret_id = azurerm_key_vault_secret.acr_password.versionless_id
    identity            = azurerm_user_assigned_identity.main.id
  }

  secret {
    name                = "db-connection-string"
    key_vault_secret_id = azurerm_key_vault_secret.db_connection_string.versionless_id
    identity            = azurerm_user_assigned_identity.main.id
  }

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "api"
      image  = "${azurerm_container_registry.main.login_server}/todo-api:latest"
      cpu    = 0.5
      memory = "1Gi"

      env {
        name        = "ConnectionStrings__DefaultConnection"
        secret_name = "db-connection-string"
      }

      env {
        name  = "ASPNETCORE_ENVIRONMENT"
        value = "Production"
      }
    }
  }

  # Internal ingress — API is only reachable from within the Container Apps environment
  ingress {
    external_enabled           = false
    allow_insecure_connections = true
    target_port                = 8080
    transport                  = "http"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
}

output "api_internal_fqdn" {
  value = azurerm_container_app.api.ingress[0].fqdn
}

# ── Web Container App ─────────────────────────────────────────────────────────
resource "azurerm_container_app" "web" {
  name                         = "ca-web-${local.name_prefix}"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.main.id]
  }

  registry {
    server               = azurerm_container_registry.main.login_server
    username             = azurerm_container_registry.main.admin_username
    password_secret_name = "acr-password"
  }

  secret {
    name                = "acr-password"
    key_vault_secret_id = azurerm_key_vault_secret.acr_password.versionless_id
    identity            = azurerm_user_assigned_identity.main.id
  }

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "web"
      image  = "${azurerm_container_registry.main.login_server}/todo-web:v6"
      cpu    = 0.25
      memory = "0.5Gi"

      # nginx uses this at startup to know where to proxy /api/ requests.
      # Points to the API's internal-only FQDN inside the Container Apps environment.
      env {
        name  = "API_URL"
        value = "http://${azurerm_container_app.api.ingress[0].fqdn}"
      }

      env {
        name  = "NGINX_ENVSUBST_FILTER"
        value = "API_URL"
      }
    }
  }

  # External ingress — publicly reachable from the internet on port 80/443
  ingress {
    external_enabled = true
    target_port      = 80
    transport        = "http"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
}

output "web_url" {
  value = "https://${azurerm_container_app.web.ingress[0].fqdn}"
}

# ── Monitoring ────────────────────────────────────────────────────────────────

# Action group — defines WHERE alerts are sent when they fire.
# An action group can have multiple receivers (email, SMS, webhook, etc.).
# We start with a single email; more can be added later.
resource "azurerm_monitor_action_group" "main" {
  name                = "ag-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.main.name
  short_name          = "todo-dev"  # Max 12 chars, shown in SMS/email subjects

  email_receiver {
    name          = "admin"
    email_address = "reneriosleon@gmail.com"
  }
}

# Diagnostic settings — tells Azure to send resource logs and metrics to Log
# Analytics. Without this, logs only exist inside the resource itself (not queryable).
# We wire up all three app resources to the same Log Analytics workspace.

resource "azurerm_monitor_diagnostic_setting" "cae" {
  name                       = "diag-cae-${local.name_prefix}"
  target_resource_id         = azurerm_container_app_environment.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  # Log categories are set at the Container Apps Environment level, not per app.
  # ContainerAppConsoleLogs: stdout/stderr from all apps in this environment
  # ContainerAppSystemLogs: Azure platform events (restarts, scaling, image pulls)
  enabled_log {
    category = "ContainerAppConsoleLogs"
  }

  enabled_log {
    category = "ContainerAppSystemLogs"
  }
}

resource "azurerm_monitor_diagnostic_setting" "postgres" {
  name                       = "diag-psql-${local.name_prefix}"
  target_resource_id         = azurerm_postgresql_flexible_server.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  # PostgreSQL server logs — slow queries, connections, errors
  enabled_log {
    category = "PostgreSQLLogs"
  }
}

# ── Metric Alerts ─────────────────────────────────────────────────────────────
# Metric alerts evaluate a numeric signal on a rolling time window.
# When the condition is met, the action group fires (sends email).

# Alert: too many 5xx errors on the API in the last 5 minutes.
# Requests2xx/4xx are normal; 5xx means the app is broken.
resource "azurerm_monitor_metric_alert" "api_5xx" {
  name                = "alert-api-5xx-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_container_app.api.id]
  description         = "API is returning 5xx errors"
  severity            = 1  # 0=Critical, 1=Error, 2=Warning, 3=Info, 4=Verbose
  frequency           = "PT5M"   # Evaluate every 5 minutes
  window_size         = "PT5M"   # Look back 5 minutes

  criteria {
    metric_namespace = "Microsoft.App/containerApps"
    metric_name      = "Requests"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 5

    dimension {
      name     = "statusCodeCategory"
      operator = "Include"
      values   = ["5xx"]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# Alert: API CPU above 80% — container may be struggling under load
resource "azurerm_monitor_metric_alert" "api_cpu" {
  name                = "alert-api-cpu-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_container_app.api.id]
  description         = "API CPU usage is above 80%"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"  # Sustained over 15 min, not just a spike

  criteria {
    metric_namespace = "Microsoft.App/containerApps"
    metric_name      = "UsageNanoCores"
    aggregation      = "Average"
    operator         = "GreaterThan"
    # 0.5 vCPU = 500,000,000 nanocores. 80% of that = 400,000,000
    threshold        = 400000000
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# Alert: API memory above 80% — risk of OOM kill
resource "azurerm_monitor_metric_alert" "api_memory" {
  name                = "alert-api-memory-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_container_app.api.id]
  description         = "API memory usage is above 80%"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.App/containerApps"
    metric_name      = "WorkingSetBytes"
    aggregation      = "Average"
    operator         = "GreaterThan"
    # 1Gi = 1,073,741,824 bytes. 80% = 858,993,459
    threshold        = 858993459
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

# Alert: Postgres storage above 80% — database disk may fill up
resource "azurerm_monitor_metric_alert" "postgres_storage" {
  name                = "alert-psql-storage-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_postgresql_flexible_server.main.id]
  description         = "PostgreSQL storage usage is above 80%"
  severity            = 2
  frequency           = "PT15M"
  window_size         = "PT1H"

  criteria {
    metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    metric_name      = "storage_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

