resource "azurerm_postgresql_flexible_server" "main" {
  name                = "psql-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location

  sku_name = var.sku_name
  version  = "16"
  zone     = var.zone

  delegated_subnet_id           = var.postgres_subnet_id
  private_dns_zone_id           = var.private_dns_zone_id
  public_network_access_enabled = false

  administrator_login    = var.admin_login
  administrator_password = var.admin_password

  storage_mb            = var.storage_mb
  backup_retention_days = var.backup_retention_days
  tags                  = var.tags
}

resource "azurerm_postgresql_flexible_server_database" "app" {
  name      = var.db_name
  server_id = azurerm_postgresql_flexible_server.main.id
  collation = "en_US.utf8"
  charset   = "utf8"
}
