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

variable "postgres_subnet_id" {
  description = "ID of the delegated subnet for PostgreSQL Flexible Server"
  type        = string
}

variable "private_dns_zone_id" {
  description = "ID of the private DNS zone for PostgreSQL"
  type        = string
}

variable "admin_login" {
  description = "PostgreSQL administrator login"
  type        = string
  default     = "todoadmin"
}

variable "admin_password" {
  description = "PostgreSQL administrator password (read from Key Vault)"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Name of the application database"
  type        = string
  default     = "todoapp"
}

variable "sku_name" {
  description = "PostgreSQL SKU (e.g. B_Standard_B1ms for dev, GP_Standard_D2s_v3 for prod)"
  type        = string
  default     = "B_Standard_B1ms"
}

variable "storage_mb" {
  description = "Storage size in MB (minimum 32768)"
  type        = number
  default     = 32768
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
}

variable "zone" {
  description = "Availability zone (pin to avoid recreation drift)"
  type        = string
  default     = "3"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
