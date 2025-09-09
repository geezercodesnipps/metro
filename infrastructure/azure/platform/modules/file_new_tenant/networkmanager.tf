# Create a Virtual Network Manager instance
resource "azurerm_network_manager" "network_manager" {
  provider = azurerm.network

  name                = "network-manager-${local.suffix}"
  location            = azurerm_resource_group.resource_group_network_manager.location
  resource_group_name = azurerm_resource_group.resource_group_network_manager.name
  tags                = var.tags

  scope_accesses = [
    "Connectivity",
    "SecurityAdmin",
    # "Routing" # Not supported today
  ]

  scope {
    management_group_ids = [
      azurerm_management_group.management_group_root.id
    ]
  }

  depends_on = [
    time_sleep.sleep_provider_registration_mg
  ]
}
