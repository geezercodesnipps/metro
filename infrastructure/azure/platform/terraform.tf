terraform {
  required_version = ">=0.13"

  backend "local" {
    # Configuration provided via local.tfbackend file
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.40.0" # Updated to match modules
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 2.6.0" # Updated to latest version to fix state tracking issues
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Added for intent layer multi-cloud support
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.3" # Updated
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12.1" # Updated
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.3" # Updated
    }
  }
}
