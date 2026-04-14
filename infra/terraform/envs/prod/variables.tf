variable "subscription_id" {
  description = "Azure subscription ID to deploy into"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus2"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "project" {
  description = "Short project name used in resource naming"
  type        = string
  default     = "todo"
}

variable "deployer_object_id" {
  description = "Azure AD object ID of the user or service principal running Terraform"
  type        = string
}
