# Configure the AzApi and AzureRm providers
terraform {
  required_providers {
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.15.0"
    }

    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.3.0"
    }
  }
  required_version = ">= 1.8.3"
}