resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_analytics_retention_days
  tags                = var.tags
}

resource "azurerm_container_app_environment" "main" {
  name                       = "cae-${var.name_prefix}"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  infrastructure_subnet_id   = var.container_apps_subnet_id
  tags                       = var.tags

  lifecycle {
    ignore_changes = [
      infrastructure_resource_group_name,
      workload_profile,
    ]
  }
}

resource "azurerm_container_app" "api" {
  name                         = "ca-api-${var.name_prefix}"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [var.managed_identity_id]
  }

  registry {
    server               = var.acr_login_server
    username             = var.acr_admin_username
    password_secret_name = "acr-password"
  }

  secret {
    name                = "acr-password"
    key_vault_secret_id = var.acr_password_secret_versionless_id
    identity            = var.managed_identity_id
  }

  secret {
    name                = "db-connection-string"
    key_vault_secret_id = var.db_connection_string_secret_versionless_id
    identity            = var.managed_identity_id
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = "api"
      image  = var.api_image
      cpu    = var.api_cpu
      memory = var.api_memory

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

resource "azurerm_container_app" "web" {
  name                         = "ca-web-${var.name_prefix}"
  container_app_environment_id = azurerm_container_app_environment.main.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [var.managed_identity_id]
  }

  registry {
    server               = var.acr_login_server
    username             = var.acr_admin_username
    password_secret_name = "acr-password"
  }

  secret {
    name                = "acr-password"
    key_vault_secret_id = var.acr_password_secret_versionless_id
    identity            = var.managed_identity_id
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = "web"
      image  = var.web_image
      cpu    = var.web_cpu
      memory = var.web_memory

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

# ── Custom Domain + Managed TLS Certificate ───────────────────────────────────
# The azurerm_container_app_environment_managed_certificate resource has a known
# schema bug in the azurerm provider. We use a null_resource + local-exec to
# call `az containerapp hostname bind` instead, which issues a free managed TLS
# cert and binds the custom domain in one step.
#
# This triggers whenever the web app FQDN changes (e.g., after destroy+apply),
# keeping DNS, cert, and domain binding all in sync automatically.

resource "null_resource" "custom_domain_bind" {
  count = var.custom_domain != "" ? 1 : 0

  triggers = {
    # Re-run when FQDN changes (destroy + apply gives new FQDN)
    web_fqdn      = azurerm_container_app.web.ingress[0].fqdn
    custom_domain = var.custom_domain
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "Binding custom domain ${var.custom_domain} to ${azurerm_container_app.web.name}..."
      az containerapp hostname bind \
        --resource-group ${azurerm_container_app.web.resource_group_name} \
        --name ${azurerm_container_app.web.name} \
        --environment ${azurerm_container_app_environment.main.name} \
        --hostname ${var.custom_domain} \
        --validation-method CNAME
      echo "Custom domain bound and managed TLS cert issued."
    EOT
  }
}
