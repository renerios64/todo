resource "azurerm_monitor_action_group" "main" {
  name                = "ag-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  short_name          = var.alert_short_name

  email_receiver {
    name          = "admin"
    email_address = var.alert_email
  }
}

# Diagnostic settings: log categories live at the CAE level, not per-app.
resource "azurerm_monitor_diagnostic_setting" "cae" {
  name                       = "diag-cae-${var.name_prefix}"
  target_resource_id         = var.cae_id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "ContainerAppConsoleLogs"
  }

  enabled_log {
    category = "ContainerAppSystemLogs"
  }
}

resource "azurerm_monitor_diagnostic_setting" "postgres" {
  name                       = "diag-psql-${var.name_prefix}"
  target_resource_id         = var.postgres_id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "PostgreSQLLogs"
  }
}

resource "azurerm_monitor_metric_alert" "api_5xx" {
  name                = "alert-api-5xx-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  scopes              = [var.api_app_id]
  description         = "API is returning 5xx errors"
  severity            = 1
  frequency           = "PT5M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.App/containerApps"
    metric_name      = "Requests"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = var.api_5xx_threshold

    dimension {
      name     = "statusCodeCategory"
      operator = "Include"
      values   = ["5xx"]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

resource "azurerm_monitor_metric_alert" "api_cpu" {
  name                = "alert-api-cpu-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  scopes              = [var.api_app_id]
  description         = "API CPU usage is above 80%"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.App/containerApps"
    metric_name      = "UsageNanoCores"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = var.api_cpu_threshold
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

resource "azurerm_monitor_metric_alert" "api_memory" {
  name                = "alert-api-memory-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  scopes              = [var.api_app_id]
  description         = "API memory usage is above 80%"
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.App/containerApps"
    metric_name      = "WorkingSetBytes"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = var.api_memory_threshold
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}

resource "azurerm_monitor_metric_alert" "postgres_storage" {
  name                = "alert-psql-storage-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  scopes              = [var.postgres_id]
  description         = "PostgreSQL storage usage is above 80%"
  severity            = 2
  frequency           = "PT15M"
  window_size         = "PT1H"

  criteria {
    metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    metric_name      = "storage_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = var.postgres_storage_threshold
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}
