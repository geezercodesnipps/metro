# Validation checks for subscription ID overlaps
check "subscription_id_overlap_validation" {
  assert {
    condition = length(local.connectivity_management_overlap) == 0
    error_message = "Connectivity and management subscriptions cannot overlap. Found duplicate subscription IDs: ${join(", ", local.connectivity_management_overlap)}"
  }
}

resource "azurerm_resource_group" "resource_group_private_dns" {
  provider = azurerm.network

  for_each = toset(var.environments)

  name     = "rg-privatedns-${local.suffix}-${each.value}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_resource_group" "resource_group_network_manager" {
  provider = azurerm.network

  name     = "rg-network-manager-${local.suffix}"
  location = var.location
  tags     = var.tags
}

resource "azurerm_resource_group" "resource_group_ddos" {
  provider = azurerm.network

  count = var.enable_ddos_protection_plan ? 1 : 0

  name     = "rg-ddos-${local.suffix}"
  location = var.location
  tags     = var.tags
}
