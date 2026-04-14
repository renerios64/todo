locals {
  # ACR name must be globally unique and alphanumeric only (no hyphens).
  acr_name = "acr${replace(var.name_prefix, "-", "")}${substr(var.subscription_id, 0, 6)}"
}

resource "azurerm_container_registry" "main" {
  name                = local.acr_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  admin_enabled       = true
}
