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
