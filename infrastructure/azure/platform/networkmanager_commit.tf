# Sleep to ensure all network manager configurations are fully propagated before deployment
resource "time_sleep" "sleep_before_network_manager_deployment" {
  create_duration = "600s" # 10 minutes to ensure full propagation including network group memberships

  depends_on = [
    module.file_new_tenant,
    module.file_new_environment,
    module.test_vms # Wait for test VMs to be created and added to network groups
  ]
}

# Additional sleep specifically for VNet network group membership propagation
resource "time_sleep" "sleep_after_vnet_network_group_membership" {
  count           = var.deploy_test_vms ? 1 : 0
  create_duration = "300s" # 5 additional minutes for VNet network group memberships to fully propagate

  depends_on = [
    time_sleep.sleep_before_network_manager_deployment,
    module.test_vms # Ensure test VMs, VNets, and static network group memberships are fully created
  ]
}

# Commit network manager connectivity config
resource "azurerm_network_manager_deployment" "network_manager_mesh_deployment_connectivity" {
  provider = azurerm.global_network

  for_each = length(local.network_manager_connectivity_configuration_ids) > 0 ? toset(local.locations_list) : toset([])

  network_manager_id = module.file_new_tenant.network_manager_resource_id
  location           = each.key
  scope_access       = "Connectivity"

  configuration_ids = local.network_manager_connectivity_configuration_ids

  depends_on = [
    time_sleep.sleep_before_network_manager_deployment
  ]
}

# Commit network manager security admin config - Only when TiP is enabled
resource "azurerm_network_manager_deployment" "network_manager_mesh_deployment_security_admin" {
  provider = azurerm.global_network

  # Deploy security admin configurations only when TiP is enabled
  for_each = var.deploy_test_vms ? toset(local.locations_list) : toset([])

  network_manager_id = module.file_new_tenant.network_manager_resource_id
  location           = each.key
  scope_access       = "SecurityAdmin"

  configuration_ids = local.network_manager_security_admin_configuration_ids

  depends_on = [
    time_sleep.sleep_before_network_manager_deployment,
    time_sleep.sleep_after_vnet_network_group_membership, # Wait for VNet network group memberships to propagate
    module.intent_layer,
    module.test_vms # Ensure test VMs and their network group memberships are fully created
  ]
}

# Not supported today
# # Commit network manager routing config
# resource "azurerm_network_manager_deployment" "network_manager_mesh_deployment_routing" {
#   provider = azurerm.global_network

#   for_each = toset(local.locations_list)

#   network_manager_id = module.file_new_tenant.network_manager_resource_id
#   location           = each.key
#   scope_access       = "Routing"

#   configuration_ids = local.network_manager_routing_configuration_ids
# }

# Manual virtual network peering of hubs because AVNM does not provide transitive connectivity
resource "azapi_resource" "virtual_network_peering_hubs" {
  for_each = local.virtual_network_hub_peerings

  type      = "Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-01-01"
  parent_id = each.value.virtual_network_id
  name      = each.key

  body = {
    properties = {
      allowForwardedTraffic     = true
      allowGatewayTransit       = false
      allowVirtualNetworkAccess = true
      doNotVerifyRemoteGateways = false
      enableOnlyIPv6Peering     = false
      peerCompleteVnets         = true
      remoteVirtualNetwork = {
        id = each.value.remote_virtual_network_id
      }
      useRemoteGateways = false
    }
  }

  response_export_values    = ["*"]
  schema_validation_enabled = true
  locks                     = []
  ignore_casing             = false
  ignore_missing_property   = false
}

# Manual route creaton in virtual network hub (route table connected to azfw subnet)
resource "azapi_resource" "route_hubs" {
  for_each = local.virtual_network_hub_routes

  type      = "Microsoft.Network/routeTables/routes@2024-01-01"
  parent_id = each.value.route_table_id_azfw_subnet
  name      = each.key

  body = {
    properties = {
      addressPrefix    = each.value.remote_address_space_allocated
      nextHopType      = "VirtualAppliance"
      nextHopIpAddress = each.value.remote_azfw_ip_address
    }
  }

  response_export_values    = ["*"]
  schema_validation_enabled = true
  locks                     = []
  ignore_casing             = false
  ignore_missing_property   = false
}
