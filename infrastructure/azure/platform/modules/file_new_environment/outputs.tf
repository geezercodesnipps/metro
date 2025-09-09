output "azfw_ip_address" {
  description = "Specifies the private IP of the Azure Firewall."
  value       = azapi_resource.firewall.output.properties.ipConfigurations[0].properties.privateIPAddress
  sensitive   = false
}

output "virtual_network_hub_id" {
  description = "Specifies the resource id of the hub virtual network."
  value       = azapi_resource.virtual_network_hub.id
  sensitive   = false
}

output "route_table_azfw_subnet_id" {
  description = "Specifies the resource id of route table used for the azfw subnet."
  value       = azapi_resource.route_table_azfw_subnet.id
  sensitive   = false
}

output "network_manager_connectivity_configuration_ids" {
  description = "Specifies the IDs of the network manager connectivity configurations."
  value = [
    azurerm_network_manager_connectivity_configuration.regional_hub_and_spoke.id,
  ]
  sensitive = false
}

output "network_manager_routing_configuration_ids" {
  description = "Specifies the IDs of the network manager routing configurations."
  value = [
    # azapi_resource.network_manager_routing_configuration_spoke_vnets.id
  ]
  sensitive = false
}
