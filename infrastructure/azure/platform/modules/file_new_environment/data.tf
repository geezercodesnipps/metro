data "azurerm_monitor_diagnostic_categories" "diagnostic_categories_firewall" {
  resource_id = azapi_resource.firewall.id
}

data "azurerm_monitor_diagnostic_categories" "diagnostic_categories_ergw" {
  resource_id = azapi_resource.firewall.id
}

data "azurerm_monitor_diagnostic_categories" "diagnostic_categories_public_ip" {
  resource_id = azapi_resource.public_ip_ergw.id
}

data "azurerm_monitor_diagnostic_categories" "diagnostic_categories_nsg" {
  resource_id = azapi_resource.nsg_dns_resolver_inbound.id
}

data "azurerm_monitor_diagnostic_categories" "diagnostic_categories_virtual_network" {
  resource_id = azapi_resource.virtual_network_hub.id
}
