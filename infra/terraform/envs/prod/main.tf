# Root module for the prod environment.
# Same modules as dev/test — larger sizing, tighter security, stricter alerts.

locals {
  tags = {
    Environment = upper(var.environment)
  }
  name_prefix = "${var.project}-${var.environment}"
}

# ── Resource Groups ───────────────────────────────────────────────────────────

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name_prefix}-${var.location}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "secrets" {
  name     = "rg-secrets-${local.name_prefix}-${var.location}"
  location = var.location
  tags     = local.tags
}

# ── Data Sources ──────────────────────────────────────────────────────────────

data "azurerm_client_config" "current" {}

# Shared DNS zone managed independently in rg-dns.
data "azurerm_dns_zone" "main" {
  name                = "reneriosleon.com"
  resource_group_name = "rg-dns"
}

# ── DNS Records ───────────────────────────────────────────────────────────────

resource "azurerm_dns_cname_record" "web" {
  name                = "todo"
  zone_name           = data.azurerm_dns_zone.main.name
  resource_group_name = data.azurerm_dns_zone.main.resource_group_name
  ttl                 = 300
  record              = module.container_apps.web_fqdn
  tags                = local.tags
}

resource "azurerm_dns_txt_record" "web_verify" {
  name                = "asuid.todo"
  zone_name           = data.azurerm_dns_zone.main.name
  resource_group_name = data.azurerm_dns_zone.main.resource_group_name
  ttl                 = 300

  record {
    value = module.container_apps.cae_custom_domain_verification_id
  }

  tags = local.tags
}

# ── Modules ───────────────────────────────────────────────────────────────────

module "networking" {
  source              = "../../modules/networking"
  name_prefix         = local.name_prefix
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
}

module "registry" {
  source              = "../../modules/registry"
  name_prefix         = local.name_prefix
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subscription_id     = var.subscription_id

  # Standard unlocks geo-replication and content trust
  sku  = "Standard"
  tags = local.tags
}

module "keyvault" {
  source                       = "../../modules/keyvault"
  name_prefix                  = local.name_prefix
  location                     = azurerm_resource_group.secrets.location
  resource_group_name          = azurerm_resource_group.secrets.name
  identity_resource_group_name = azurerm_resource_group.main.name
  subscription_id              = var.subscription_id
  tenant_id                    = data.azurerm_client_config.current.tenant_id
  deployer_object_id           = var.deployer_object_id

  # Prod: enable purge protection so secrets can't be permanently deleted
  # accidentally. 90-day retention matches Azure's default.
  purge_protection_enabled   = true
  soft_delete_retention_days = 90
  tags                       = local.tags
}

data "azurerm_key_vault_secret" "db_password" {
  name         = "db-admin-password"
  key_vault_id = module.keyvault.key_vault_id
  depends_on   = [module.keyvault]
}

module "database" {
  source              = "../../modules/database"
  name_prefix         = local.name_prefix
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  postgres_subnet_id  = module.networking.postgres_subnet_id
  private_dns_zone_id = module.networking.postgres_private_dns_zone_id
  admin_password      = data.azurerm_key_vault_secret.db_password.value

  # Prod: General Purpose tier — dedicated vCPUs, no CPU credits to exhaust
  sku_name              = "GP_Standard_D2s_v3"  # 2 vCPU, 8 GB RAM
  storage_mb            = 131072                 # 128 GB
  backup_retention_days = 30
  tags                  = local.tags
}

# ── Key Vault Secrets (glue) ──────────────────────────────────────────────────

resource "azurerm_key_vault_secret" "db_connection_string" {
  name         = "db-connection-string"
  value        = "Host=${module.database.fqdn};Database=todoapp;Username=todoadmin;Password=${data.azurerm_key_vault_secret.db_password.value};SSL Mode=Require"
  key_vault_id = module.keyvault.key_vault_id
  depends_on   = [module.keyvault]
}

resource "azurerm_key_vault_secret" "acr_password" {
  name         = "acr-admin-password"
  value        = module.registry.admin_password
  key_vault_id = module.keyvault.key_vault_id
  depends_on   = [module.keyvault]
}

# ── Container Apps ────────────────────────────────────────────────────────────

module "container_apps" {
  source              = "../../modules/container_apps"
  name_prefix         = local.name_prefix
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  container_apps_subnet_id = module.networking.container_apps_subnet_id

  acr_login_server   = module.registry.login_server
  acr_admin_username = module.registry.admin_username

  acr_password_secret_versionless_id         = azurerm_key_vault_secret.acr_password.versionless_id
  db_connection_string_secret_versionless_id = azurerm_key_vault_secret.db_connection_string.versionless_id

  managed_identity_id = module.keyvault.managed_identity_id

  # Prod images should be pinned to explicit tags, never "latest"
  api_image = "${module.registry.login_server}/todo-api:latest"
  web_image = "${module.registry.login_server}/todo-web:latest"

  # Prod: double the CPU and memory vs dev
  api_cpu    = 1.0
  api_memory = "2Gi"
  web_cpu    = 0.5
  web_memory = "1Gi"

  # Prod: always-on with room to scale under load
  min_replicas = 2
  max_replicas = 5

  # Keep prod logs longer
  log_analytics_retention_days = 90
  tags                         = local.tags

  custom_domain = "todo.reneriosleon.com"
}

# ── Monitoring ────────────────────────────────────────────────────────────────

module "monitoring" {
  source              = "../../modules/monitoring"
  name_prefix         = local.name_prefix
  resource_group_name = azurerm_resource_group.main.name

  log_analytics_workspace_id = module.container_apps.log_analytics_workspace_id
  cae_id                     = module.container_apps.cae_id
  api_app_id                 = module.container_apps.api_id
  postgres_id                = module.database.id

  alert_email      = "reneriosleon@gmail.com"
  alert_short_name = "todo-prod"

  # Prod: tighter thresholds — alert earlier before users feel the impact
  api_5xx_threshold          = 2                # fire on just 2 errors (vs 5 in dev)
  api_cpu_threshold          = 700000000        # 70% of 1.0 vCPU
  api_memory_threshold       = 1503238554       # 70% of 2Gi
  postgres_storage_threshold = 75               # tighter storage warning
  tags                       = local.tags
}

# ── Outputs ───────────────────────────────────────────────────────────────────

output "acr_login_server"  { value = module.registry.login_server }
output "db_host"           { value = module.database.fqdn }
output "key_vault_uri"     { value = module.keyvault.key_vault_uri }
output "aca_environment_id"{ value = module.container_apps.cae_id }
output "api_internal_fqdn" { value = module.container_apps.api_fqdn }
output "web_url"           { value = module.container_apps.web_url }
