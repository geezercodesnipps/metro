terraform {
  required_version = ">=0.13"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.40.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = ">= 1.14.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.2"
    }
    time = {
      source  = "hashicorp/time"
      version = ">= 0.11.2"
    }
  }
}
