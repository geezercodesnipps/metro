terraform {
  required_version = ">=0.13"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.40.0"
      configuration_aliases = [
        azurerm.network,
      ]
    }
    azapi = {
      source  = "Azure/azapi"
      version = ">= 1.14.0"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.11.2"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.2"
    }
  }
}
