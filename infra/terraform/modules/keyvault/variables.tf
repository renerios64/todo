variable "name_prefix" {
  description = "Consistent name prefix for all resources (e.g. todo-dev)"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the secrets resource group for Key Vault (isolated from main RG)"
  type        = string
}

variable "identity_resource_group_name" {
  description = "Name of the main resource group where the managed identity lives"
  type        = string
}

variable "subscription_id" {
  description = "Azure subscription ID — first 6 chars used as unique suffix"
  type        = string
}

variable "tenant_id" {
  description = "Azure AD tenant ID (from data.azurerm_client_config)"
  type        = string
}

variable "deployer_object_id" {
  description = "Object ID of the identity running Terraform (gets Secrets Officer role)"
  type        = string
}

variable "purge_protection_enabled" {
  description = "Enable purge protection (should be true in prod)"
  type        = bool
  default     = false
}

variable "soft_delete_retention_days" {
  description = "Days to retain soft-deleted secrets (7 minimum)"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
