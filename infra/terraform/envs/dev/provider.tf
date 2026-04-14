terraform {
  required_version = ">= 1.11"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Remote state — stored in Azure Blob Storage.
  # One state file per environment: envs/dev → dev/terraform.tfstate
  # The storage account lives in rg-tfstate (separate from all app RGs)
  # so it survives terraform destroy of any environment.
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstatea8ca4a"
    container_name       = "tfstate"
    key                  = "dev/terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
