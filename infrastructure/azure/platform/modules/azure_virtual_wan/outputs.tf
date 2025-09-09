# Outputs for Azure Virtual WAN Module

output "virtual_wan_id" {
  description = "The ID of the Virtual WAN"
  value       = azurerm_virtual_wan.vwan.id
}

output "virtual_wan_name" {
  description = "The name of the Virtual WAN"
  value       = azurerm_virtual_wan.vwan.name
}

output "virtual_hubs" {
  description = "Details of all Virtual Hubs"
  value = {
    for key, hub in azurerm_virtual_hub.vhub : key => {
      id                = hub.id
      name              = hub.name
      location          = hub.location
      address_prefix    = hub.address_prefix
      virtual_router_asn = hub.virtual_router_asn
      virtual_router_ips = hub.virtual_router_ips
    }
  }
}

output "virtual_hub_ids" {
  description = "Map of Virtual Hub IDs by key"
  value = {
    for key, hub in azurerm_virtual_hub.vhub : key => hub.id
  }
}

output "expressroute_gateways" {
  description = "Details of ExpressRoute Gateways"
  value = {
    for key, gateway in azurerm_express_route_gateway.er_gateway : key => {
      id         = gateway.id
      name       = gateway.name
      location   = gateway.location
      scale_units = gateway.scale_units
    }
  }
}

output "vpn_gateways" {
  description = "Details of VPN Gateways"
  value = {
    for key, gateway in azurerm_vpn_gateway.vpn_gateway : key => {
      id         = gateway.id
      name       = gateway.name
      location   = gateway.location
      scale_unit = gateway.scale_unit
    }
  }
}

output "hub_firewalls" {
  description = "Details of Hub Firewalls"
  value = {
    for key, firewall in azurerm_firewall.hub_firewall : key => {
      id                = firewall.id
      name              = firewall.name
      location          = firewall.location
      # Virtual WAN firewalls don't have ip_configuration like regular firewalls
      # They get their IPs automatically from the virtual hub
      virtual_hub_id    = firewall.virtual_hub[0].virtual_hub_id
      public_ip_count   = firewall.virtual_hub[0].public_ip_count
    }
  }
}

output "firewall_policies" {
  description = "Details of Firewall Policies"
  value = {
    for key, policy in azurerm_firewall_policy.policy : key => {
      id       = policy.id
      name     = policy.name
      location = policy.location
    }
  }
}

# Compatibility outputs for platform integration
output "firewall_ids" {
  description = "Map of Firewall IDs by key"
  value = {
    for key, firewall in azurerm_firewall.hub_firewall : key => firewall.id
  }
}

output "firewall_policy_ids" {
  description = "Map of Firewall Policy IDs by key"
  value = {
    for key, policy in azurerm_firewall_policy.policy : key => policy.id
  }
}

output "vnet_connections" {
  description = "Details of VNet connections to Virtual Hubs"
  value = {
    for key, connection in azurerm_virtual_hub_connection.vnet_connections : key => {
      id                        = connection.id
      name                      = connection.name
      virtual_hub_id            = connection.virtual_hub_id
      remote_virtual_network_id = connection.remote_virtual_network_id
      routing_state            = connection.routing.*.associated_route_table_id
    }
  }
}

output "custom_route_tables" {
  description = "Details of custom route tables"
  value = {
    for key, table in azurerm_virtual_hub_route_table.custom_route_tables : key => {
      id             = table.id
      name           = table.name
      virtual_hub_id = table.virtual_hub_id
      labels         = table.labels
    }
  }
}

# Outputs for migration from traditional hub-spoke
output "migration_info" {
  description = "Information to help with migration from traditional hub-spoke"
  value = {
    virtual_wan_resource_id = azurerm_virtual_wan.vwan.id
    hub_count              = length(azurerm_virtual_hub.vhub)
    # Virtual WAN firewalls don't expose private IP addresses the same way
    hub_firewall_ids       = {
      for key, firewall in azurerm_firewall.hub_firewall : key => firewall.id
    }
    hub_router_asns = {
      for key, hub in azurerm_virtual_hub.vhub : key => hub.virtual_router_asn
    }
  }
}

# Useful for Network Manager integration
output "hub_virtual_network_ids" {
  description = "Virtual network IDs of the Virtual Hubs for Network Manager"
  value = {
    for key, hub in azurerm_virtual_hub.vhub : key => hub.id  # Use hub.id instead of virtual_network_id
  }
}

# Network Manager Configuration outputs to match file_new_environment module interface
output "network_manager_connectivity_configuration_ids" {
  description = "IDs of Network Manager connectivity configurations (Virtual WAN uses different connectivity model)"
  value       = []  # Virtual WAN hubs don't use connectivity configurations - they use direct peering
}

output "network_manager_security_admin_configuration_ids" {
  description = "IDs of Network Manager security admin configurations - VWAN uses tenant's security admin config"
  value = []  # Virtual WAN no longer creates its own security admin configuration - uses tenant's
}

output "network_manager_routing_configuration_ids" {
  description = "IDs of Network Manager routing configurations (Virtual WAN uses built-in routing)"
  value = []  # Virtual WAN handles routing internally - no custom routing configurations needed
}

# AVNM Security Admin Configuration Outputs
output "security_admin_configuration_id" {
  description = "The ID of the security admin configuration - VWAN uses tenant's security admin config"
  value       = var.enable_network_manager_integration ? var.network_manager_config.security_admin_configuration_id : null
}

output "network_group_ids" {
  description = "The IDs of the network groups created for segmentation"
  value = var.enable_network_manager_integration ? {
    prod    = azurerm_network_manager_network_group.prod_network_group[0].id
    nonprod = azurerm_network_manager_network_group.nonprod_network_group[0].id
  } : {}
}
