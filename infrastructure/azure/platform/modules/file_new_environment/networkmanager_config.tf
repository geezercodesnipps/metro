# Create a network group
resource "azurerm_network_manager_network_group" "regional_spoke_vnets" {
  provider = azurerm.global_network

  name               = "spoke-vnets-network-group-${local.suffix}"
  network_manager_id = var.network_manager_resource_id
}

# Create a connectivity configuration
resource "azurerm_network_manager_connectivity_configuration" "regional_hub_and_spoke" {
  provider = azurerm.global_network

  name                  = "hub-and-spoke-configuration-${local.suffix}"
  network_manager_id    = var.network_manager_resource_id
  connectivity_topology = "HubAndSpoke"

  applies_to_group {
    group_connectivity = "None"
    network_group_id   = azurerm_network_manager_network_group.regional_spoke_vnets.id
    use_hub_gateway    = true
  }

  hub {
    resource_id   = azapi_resource.virtual_network_hub.id
    resource_type = "Microsoft.Network/virtualNetworks"
  }

  delete_existing_peering_enabled = true
}

# Not supported today
# # Create routing configuration
# resource "azapi_resource" "network_manager_routing_configuration_spoke_vnets" {
#   type      = "Microsoft.Network/networkManagers/routingConfigurations@2023-03-01-preview"
#   parent_id = var.network_manager_resource_id
#   name      = "routing-configuration-${local.suffix}"

#   body = {
#     properties = {
#       description = "Environmental routing configuration (${local.suffix})"
#     }
#   }

#   response_export_values    = ["*"]
#   schema_validation_enabled = true
#   locks                     = []
#   ignore_casing             = false
#   ignore_missing_property   = false
# }

# # Create routing rule collection
# resource "azapi_resource" "network_manager_routing_rule_collection_spoke_vnets" {
#   type      = "Microsoft.Network/networkManagers/routingConfigurations/ruleCollections@2023-03-01-preview"
#   parent_id = var.network_manager_resource_id
#   name      = "routing-rule-collection-${local.suffix}"

#   body = {
#     properties = {
#       appliesTo = [
#         {
#           networkGroupId = azurerm_network_manager_network_group.regional_spoke_vnets.id
#         }
#       ]
#       localRouteSetting          = "DirectRoutingWithinVNet"
#       description                = "Environmental routing rule collection (${local.suffix})"
#       disableBgpRoutePropagation = var.disable_bgp_route_propagation
#     }
#   }

#   response_export_values    = ["*"]
#   schema_validation_enabled = true
#   locks                     = []
#   ignore_casing             = false
#   ignore_missing_property   = false
# }

# # Create routing rules
# resource "azapi_resource" "network_manager_routing_rule_collection_spoke_vnets_default_route" {
#   type      = "Microsoft.Network/networkManagers/routingConfigurations/ruleCollections/rules@2023-03-01-preview"
#   parent_id = var.network_manager_resource_id
#   name      = "default-route"

#   body = {
#     properties = {
#       description = "Default Routing Rule for spoke VNets"
#       destination = {
#         destinationAddress = "0.0.0.0/0"
#         type               = "AddressPrefix"
#       }
#       nextHop = {
#         nextHopType    = "VirtualAppliance"
#         nextHopAddress = azapi_resource.firewall.output.properties.ipConfigurations[0].properties.privateIPAddress
#       }
#     }
#   }

#   response_export_values    = ["*"]
#   schema_validation_enabled = true
#   locks                     = []
#   ignore_casing             = false
#   ignore_missing_property   = false
# }
