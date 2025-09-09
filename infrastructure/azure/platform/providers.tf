provider "azurerm" {
  disable_correlation_request_id = false
  environment                    = "public"
  storage_use_azuread            = true
  subscription_id                = var.global_platform_subscription_id

  features {
    application_insights {
      disable_generated_rule = false
    }
    cognitive_account {
      purge_soft_delete_on_destroy = true
    }
    key_vault {
      purge_soft_delete_on_destroy               = true
      purge_soft_deleted_certificates_on_destroy = true
      purge_soft_deleted_keys_on_destroy         = true
      purge_soft_deleted_secrets_on_destroy      = true
      recover_soft_deleted_key_vaults            = true
      recover_soft_deleted_certificates          = true
      recover_soft_deleted_keys                  = true
      recover_soft_deleted_secrets               = true
    }
    log_analytics_workspace {
      permanently_delete_on_destroy = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}

provider "azurerm" {
  alias                          = "global_network"
  disable_correlation_request_id = false
  environment                    = "public"
  storage_use_azuread            = true
  subscription_id                = var.global_platform_subscription_id

  features {
    application_insights {
      disable_generated_rule = false
    }
    cognitive_account {
      purge_soft_delete_on_destroy = true
    }
    key_vault {
      purge_soft_delete_on_destroy               = true
      purge_soft_deleted_certificates_on_destroy = true
      purge_soft_deleted_keys_on_destroy         = true
      purge_soft_deleted_secrets_on_destroy      = true
      recover_soft_deleted_key_vaults            = true
      recover_soft_deleted_certificates          = true
      recover_soft_deleted_keys                  = true
      recover_soft_deleted_secrets               = true
    }
    log_analytics_workspace {
      permanently_delete_on_destroy = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}

provider "azapi" {
  default_location               = var.location
  default_tags                   = var.tags
  disable_correlation_request_id = false
  environment                    = "public"
  skip_provider_registration     = false
}

# AWS Provider for Intent Layer Multi-Cloud Support
# This provider is used only when AWS intent features are enabled
provider "aws" {
  # Configure AWS region based on Azure region mapping
  region = local.aws_region_mapping[var.location]

  # Skip all validations to prevent credential issues when AWS is not used
  skip_credentials_validation = true
  skip_region_validation      = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}

provider "aws" {
  alias  = "intent_layer"
  region = local.aws_region_mapping[var.location]

  # Skip all validations to prevent credential issues when AWS is not used
  skip_credentials_validation = true
  skip_region_validation      = true
  skip_requesting_account_id  = true
  skip_metadata_api_check     = true
}
