variable "name_prefix" {
  description = "Consistent name prefix for all resources (e.g. todo-dev)"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group to deploy into"
  type        = string
}

variable "container_apps_subnet_id" {
  description = "ID of the subnet for the Container Apps Environment"
  type        = string
}

variable "acr_login_server" {
  description = "ACR login server hostname (e.g. acrtododeva8ca4a.azurecr.io)"
  type        = string
}

variable "acr_admin_username" {
  description = "ACR admin username"
  type        = string
}

variable "acr_password_secret_versionless_id" {
  description = "Versionless Key Vault secret ID for the ACR password"
  type        = string
}

variable "db_connection_string_secret_versionless_id" {
  description = "Versionless Key Vault secret ID for the DB connection string"
  type        = string
}

variable "managed_identity_id" {
  description = "Resource ID of the user-assigned managed identity"
  type        = string
}

variable "api_image" {
  description = "Full image reference for the API (e.g. acr.azurecr.io/todo-api:v2)"
  type        = string
}

variable "web_image" {
  description = "Full image reference for the Web app (e.g. acr.azurecr.io/todo-web:v6)"
  type        = string
}

variable "api_cpu" {
  description = "vCPU allocation for the API container"
  type        = number
  default     = 0.5
}

variable "api_memory" {
  description = "Memory allocation for the API container (e.g. 1Gi)"
  type        = string
  default     = "1Gi"
}

variable "web_cpu" {
  description = "vCPU allocation for the Web container"
  type        = number
  default     = 0.25
}

variable "web_memory" {
  description = "Memory allocation for the Web container (e.g. 0.5Gi)"
  type        = string
  default     = "0.5Gi"
}

variable "min_replicas" {
  description = "Minimum replicas for both apps (0 = scale to zero)"
  type        = number
  default     = 1
}

variable "max_replicas" {
  description = "Maximum replicas for both apps"
  type        = number
  default     = 1
}

variable "log_analytics_retention_days" {
  description = "Log Analytics workspace retention in days"
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "custom_domain" {
  description = "Custom domain to bind to the web Container App (e.g. todo.reneriosleon.com). Leave empty to skip."
  type        = string
  default     = ""
}
