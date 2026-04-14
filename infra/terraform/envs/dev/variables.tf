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

variable "deployer_object_id" {
  description = "Azure AD object ID of the user or service principal running Terraform. Granted Key Vault Secrets Officer so Terraform can write secrets."
  type        = string
}
