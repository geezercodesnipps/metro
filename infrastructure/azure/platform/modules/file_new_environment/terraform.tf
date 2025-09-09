terraform {
  required_version = ">=0.13"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.40.0"
      configuration_aliases = [
        azurerm.global_network
      ]
    }
    azapi = {
      source  = "Azure/azapi"
      version = ">= 1.14.0"
    }
  }
}
