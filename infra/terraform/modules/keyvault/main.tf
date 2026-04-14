locals {
  # Key Vault name: max 24 chars, alphanumeric + hyphens, globally unique.
  kv_name = "kv-${var.name_prefix}-${substr(var.subscription_id, 0, 6)}"
}

# User-assigned managed identity — lives in the main RG (not secrets RG)
# so it travels with the app infrastructure, not the vault.
resource "azurerm_user_assigned_identity" "main" {
  name                = "mi-${var.name_prefix}"
  resource_group_name = var.identity_resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_key_vault" "main" {
  name                = local.kv_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tenant_id           = var.tenant_id
  sku_name            = "standard"

  rbac_authorization_enabled = true
  purge_protection_enabled   = var.purge_protection_enabled
  soft_delete_retention_days = var.soft_delete_retention_days
  tags                       = var.tags
}

# Grant the deployer (Terraform runner) permission to read/write secrets.
resource "azurerm_role_assignment" "deployer_secrets_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.deployer_object_id
}

# Grant the managed identity permission to READ secrets at runtime.
resource "azurerm_role_assignment" "mi_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
}
