resource "azurerm_network_ddos_protection_plan" "network_ddos_protection_plan" {
  provider = azurerm.network

  count = var.enable_ddos_protection_plan ? 1 : 0

  name                = "ddos-${local.suffix}"
  location            = var.location
  resource_group_name = one(azurerm_resource_group.resource_group_ddos[*].name)
  tags                = var.tags
}
