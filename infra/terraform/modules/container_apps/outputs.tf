output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.main.id
}

output "cae_id" {
  value = azurerm_container_app_environment.main.id
}

output "api_fqdn" {
  value = azurerm_container_app.api.ingress[0].fqdn
}

output "api_id" {
  value = azurerm_container_app.api.id
}

output "web_url" {
  value = "https://${azurerm_container_app.web.ingress[0].fqdn}"
}
