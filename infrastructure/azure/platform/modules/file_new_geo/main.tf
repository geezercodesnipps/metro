# Validation checks for denied resource types against allowed resource providers
check "denied_resource_types_validation" {
  assert {
    condition = length(local.invalid_denied_resource_types) == 0
    error_message = "The following denied resource types are not in the list of allowed resource providers: ${join(", ", local.invalid_denied_resource_types)}. Please specify resources included in the list of allowed resource providers."
  }
}

# Resource group for logs - using azurerm provider which handles existing resources better
resource "azurerm_resource_group" "resource_group_logs" {
  name     = "rg-logs-${local.suffix}"
  location = var.location
  tags     = var.tags

  # Prevent accidental deletion of existing resource groups
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_resource_group" "resource_group_identity" {
  name     = "rg-identity-${local.suffix}"
  location = var.location
  tags     = var.tags

  # Prevent accidental deletion of existing resource groups
  lifecycle {
    prevent_destroy = true
  }
}
