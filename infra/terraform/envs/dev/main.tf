# Root module for the dev environment.
# Calls shared modules and wires their inputs/outputs together.
# "Glue" resources that depend on outputs from multiple modules live here.

locals {
  name_prefix = "${var.project}-${var.environment}"
  tags = {
    Environment = upper(var.environment)
  }
}

# ── Resource Groups ───────────────────────────────────────────────────────────

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name_prefix}-${var.location}"
  location = var.location
  tags     = local.tags
}

# Key Vault lives in its own RG so it survives terraform destroy of the main RG.
resource "azurerm_resource_group" "secrets" {
  name     = "rg-secrets-${local.name_prefix}-${var.location}"
  location = var.location
  tags     = local.tags
}

# ── Data Sources ──────────────────────────────────────────────────────────────

# Current Terraform runner identity — used to pass tenant_id to Key Vault.
data "azurerm_client_config" "current" {}

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
  tags                = local.tags
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
  tags                         = local.tags
}

# Read the bootstrap DB password from Key Vault.
# This secret was seeded once manually and never changes via Terraform.
# It must exist before the database module can create Postgres.
data "azurerm_key_vault_secret" "db_password" {
  name         = "db-admin-password"
  key_vault_id = module.keyvault.key_vault_id

  depends_on = [module.keyvault]
}

module "database" {
  source              = "../../modules/database"
  name_prefix         = local.name_prefix
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  postgres_subnet_id  = module.networking.postgres_subnet_id
  private_dns_zone_id = module.networking.postgres_private_dns_zone_id
  admin_password      = data.azurerm_key_vault_secret.db_password.value
  tags                = local.tags
}

# ── Key Vault Secrets (glue) ──────────────────────────────────────────────────
# These depend on outputs from multiple modules so they live in root, not in
# either module individually.

resource "azurerm_key_vault_secret" "db_connection_string" {
  name         = "db-connection-string"
  value        = "Host=${module.database.fqdn};Database=todoapp;Username=todoadmin;Password=${data.azurerm_key_vault_secret.db_password.value};SSL Mode=Require"
  key_vault_id = module.keyvault.key_vault_id

  depends_on = [module.keyvault]
}

resource "azurerm_key_vault_secret" "acr_password" {
  name         = "acr-admin-password"
  value        = module.registry.admin_password
  key_vault_id = module.keyvault.key_vault_id

  depends_on = [module.keyvault]
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

  acr_password_secret_versionless_id          = azurerm_key_vault_secret.acr_password.versionless_id
  db_connection_string_secret_versionless_id  = azurerm_key_vault_secret.db_connection_string.versionless_id

  managed_identity_id = module.keyvault.managed_identity_id

  api_image = "${module.registry.login_server}/todo-api:latest"
  web_image = "${module.registry.login_server}/todo-web:v6"
  tags      = local.tags
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
  alert_short_name = "todo-dev"
  tags             = local.tags
}

# ── Outputs ───────────────────────────────────────────────────────────────────

output "acr_login_server" {
  value = module.registry.login_server
}

output "db_host" {
  value = module.database.fqdn
}

output "key_vault_uri" {
  value = module.keyvault.key_vault_uri
}

output "aca_environment_id" {
  value = module.container_apps.cae_id
}

output "api_internal_fqdn" {
  value = module.container_apps.api_fqdn
}

output "web_url" {
  value = module.container_apps.web_url
}

