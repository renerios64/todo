variable "subscription_id" {
  description = "Azure subscription ID to deploy into"
  type        = string
}

variable "location" {
  description = "Azure region (e.g. eastus, westus2, centralus)"
  type        = string
  default     = "eastus"
}

variable "environment" {
  description = "Environment name (dev, test, prod)"
  type        = string
  default     = "dev"
}

variable "project" {
  description = "Short project name used in resource naming"
  type        = string
  default     = "todo"
}

variable "db_admin_password" {
  description = "PostgreSQL administrator password. Set via TF_VAR_db_admin_password env var — never hardcode."
  type        = string
  sensitive   = true
}
