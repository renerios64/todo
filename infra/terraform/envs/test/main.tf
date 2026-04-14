# Root module for the test environment.
# Same modules as dev — only variable values differ.

locals {
  name_prefix = "${var.project}-${var.environment}"
}

# ── Resource Groups ───────────────────────────────────────────────────────────

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name_prefix}-${var.location}"
  location = var.location
}

resource "azurerm_resource_group" "secrets" {
  name     = "rg-secrets-${local.name_prefix}-${var.location}"
  location = var.location
}

# ── Data Sources ──────────────────────────────────────────────────────────────

data "azurerm_client_config" "current" {}

# ── Modules ───────────────────────────────────────────────────────────────────

module "networking" {
  source              = "../../modules/networking"
  name_prefix         = local.name_prefix
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

module "registry" {
  source              = "../../modules/registry"
  name_prefix         = local.name_prefix
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subscription_id     = var.subscription_id
  sku                 = "Basic"
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

  # Same as dev — purge protection off for easy cleanup
  purge_protection_enabled   = false
  soft_delete_retention_days = 7
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

  # Same size as dev — test validates behavior, not load capacity
  sku_name              = "B_Standard_B1ms"
  storage_mb            = 32768
  backup_retention_days = 7
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

  api_image = "${module.registry.login_server}/todo-api:latest"
  web_image = "${module.registry.login_server}/todo-web:latest"

  # Same sizing as dev — test mirrors dev behavior
  api_cpu    = 0.5
  api_memory = "1Gi"
  web_cpu    = 0.25
  web_memory = "0.5Gi"

  # Keep at least 1 replica — test should always be reachable
  min_replicas = 1
  max_replicas = 2
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
  alert_short_name = "todo-test"

  # Same thresholds as dev
  api_5xx_threshold          = 5
  api_cpu_threshold          = 400000000  # 80% of 0.5 vCPU
  api_memory_threshold       = 858993459  # 80% of 1Gi
  postgres_storage_threshold = 80
}

# ── Outputs ───────────────────────────────────────────────────────────────────

output "acr_login_server"  { value = module.registry.login_server }
output "db_host"           { value = module.database.fqdn }
output "key_vault_uri"     { value = module.keyvault.key_vault_uri }
output "aca_environment_id"{ value = module.container_apps.cae_id }
output "api_internal_fqdn" { value = module.container_apps.api_fqdn }
output "web_url"           { value = module.container_apps.web_url }
