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
  administrator_password = var.db_admin_password

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

# ── Container Apps Environment ────────────────────────────────────────────────

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
  db_connection_string = "Host=${azurerm_postgresql_flexible_server.main.fqdn};Database=todoapp;Username=todoadmin;Password=${var.db_admin_password};SSL Mode=Require"
}

resource "azurerm_container_app" "api" {
  name                         = "ca-api-${local.name_prefix}"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = azurerm_resource_group.main.name
  revision_mode                = "Single"

  # ACR credentials so the environment can pull our image
  registry {
    server               = azurerm_container_registry.main.login_server
    username             = azurerm_container_registry.main.admin_username
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = azurerm_container_registry.main.admin_password
  }

  secret {
    name  = "db-connection-string"
    value = local.db_connection_string
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

  registry {
    server               = azurerm_container_registry.main.login_server
    username             = azurerm_container_registry.main.admin_username
    password_secret_name = "acr-password"
  }

  secret {
    name  = "acr-password"
    value = azurerm_container_registry.main.admin_password
  }

  template {
    min_replicas = 1
    max_replicas = 1

    container {
      name   = "web"
      image  = "${azurerm_container_registry.main.login_server}/todo-web:latest"
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

