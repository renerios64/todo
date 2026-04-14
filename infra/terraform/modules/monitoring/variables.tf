variable "name_prefix" {
  description = "Consistent name prefix for all resources (e.g. todo-dev)"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group to deploy into"
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace for diagnostic settings"
  type        = string
}

variable "cae_id" {
  description = "Resource ID of the Container Apps Environment"
  type        = string
}

variable "api_app_id" {
  description = "Resource ID of the API Container App"
  type        = string
}

variable "postgres_id" {
  description = "Resource ID of the PostgreSQL Flexible Server"
  type        = string
}

variable "alert_email" {
  description = "Email address for alert notifications"
  type        = string
}

variable "alert_short_name" {
  description = "Short name for the action group (max 12 chars)"
  type        = string
}

variable "api_cpu_threshold" {
  description = "CPU nanocores threshold for API CPU alert (e.g. 400000000 = 80% of 0.5 vCPU)"
  type        = number
  default     = 400000000
}

variable "api_memory_threshold" {
  description = "Memory bytes threshold for API memory alert (e.g. 858993459 = 80% of 1Gi)"
  type        = number
  default     = 858993459
}

variable "api_5xx_threshold" {
  description = "Number of 5xx errors in the window before alerting"
  type        = number
  default     = 5
}

variable "postgres_storage_threshold" {
  description = "Postgres storage percentage threshold before alerting"
  type        = number
  default     = 80
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
