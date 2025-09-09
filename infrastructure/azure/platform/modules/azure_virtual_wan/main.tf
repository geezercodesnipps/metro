# ================================================================
# IMPORTANT NOTE: test-vm-connectivity-rules-FSI003 rule collection is intentionally 
# disabled in this module (around line 330) because all test VM rules are now 
# properly defined in the intent-layer-rules-FSI003 rule collection.
# DO NOT REMOVE THIS FIX - Otherwise deployment will fail with:
# "should contain at least one item for deployment" error.
# ================================================================

# Virtual WAN instance - This will be one for each tenant
resource "azurerm_virtual_wan" "vwan" {
  name                = "vwan-${var.suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  
  # Standard SKU required for ExpressRoute, secure hubs, and advanced features
  type = "Standard"
  
  # Enable automatic branch-to-branch connectivity
  allow_branch_to_branch_traffic         = true
  disable_vpn_encryption                = false
  
  # For production environments with dual hubs per region
  office365_local_breakout_category = "OptimizeAndAllow"
  
  tags = var.tags
}

# Virtual Hub for each environment in each region
resource "azurerm_virtual_hub" "vhub" {
  for_each = var.virtual_hubs
  
  name                = "vhub-${each.key}-${var.suffix}"
  resource_group_name = var.resource_group_name
  location            = each.value.location
  virtual_wan_id      = azurerm_virtual_wan.vwan.id
  address_prefix      = each.value.address_prefix
  
  # Hub routing preference - Use AS Path for optimal routing
  hub_routing_preference = "ASPath"
  
  # SKU must be Standard for secure hub capabilities
  sku = "Standard"
  
  tags = merge(var.tags, {
    Environment = each.value.environment
    Region      = each.value.location
  })
}

# ExpressRoute Gateway in each virtual hub
resource "azurerm_express_route_gateway" "er_gateway" {
  for_each = { 
    for key, hub in var.virtual_hubs : key => hub 
    if hub.enable_expressroute_gateway 
  }
  
  name                = "ergw-${each.key}-${var.suffix}"
  resource_group_name = var.resource_group_name
  location            = each.value.location
  virtual_hub_id      = azurerm_virtual_hub.vhub[each.key].id
  
  scale_units = each.value.expressroute_scale_units
  
  tags = merge(var.tags, {
    Environment = each.value.environment
    Region      = each.value.location
  })
  
  depends_on = [azurerm_virtual_hub.vhub]
}

# VPN Gateway in each virtual hub (if enabled)
resource "azurerm_vpn_gateway" "vpn_gateway" {
  for_each = { 
    for key, hub in var.virtual_hubs : key => hub 
    if hub.enable_vpn_gateway 
  }
  
  name                = "vpngw-${each.key}-${var.suffix}"
  resource_group_name = var.resource_group_name
  location            = each.value.location
  virtual_hub_id      = azurerm_virtual_hub.vhub[each.key].id
  
  # Scale units for VPN Gateway
  scale_unit = each.value.vpn_scale_units
  
  tags = merge(var.tags, {
    Environment = each.value.environment
    Region      = each.value.location
  })
  
  depends_on = [azurerm_virtual_hub.vhub]
}

# Azure Firewall in each virtual hub for secure hub functionality
resource "azurerm_firewall" "hub_firewall" {
  for_each = { 
    for key, hub in var.virtual_hubs : key => hub 
    if hub.enable_firewall 
  }
  
  name                = "azfw-${each.key}-${var.suffix}"
  resource_group_name = var.resource_group_name
  location            = each.value.location
  sku_name            = "AZFW_Hub"  # Virtual WAN requires AZFW_Hub SKU
  sku_tier            = each.value.firewall_sku
  firewall_policy_id  = azurerm_firewall_policy.policy[each.value.environment].id
  
  virtual_hub {
    virtual_hub_id   = azurerm_virtual_hub.vhub[each.key].id
    public_ip_count  = each.value.firewall_public_ip_count
  }
  
  # Availability zones for high availability
  zones = ["1", "2", "3"]
  
  tags = merge(var.tags, {
    Environment = each.value.environment
    Region      = each.value.location
  })
  
  depends_on = [
    azurerm_virtual_hub.vhub,
    azurerm_firewall_policy.policy
  ]
}

# Firewall Policy for each environment type
resource "azurerm_firewall_policy" "policy" {
  for_each = var.firewall_policies
  
  name                = "fwpolicy-${each.key}-${var.suffix}"
  resource_group_name = var.resource_group_name
  location            = each.value.location
  sku                 = each.value.sku
  
  # Basic threat intelligence (available in Standard SKU)
  threat_intelligence_mode = "Alert"
  
  # Removed Premium features to reduce cost:
  # - DNS proxy (Premium only)
  # - Intrusion detection system (Premium only)
  # - Custom DNS servers (Premium only)
  
  tags = merge(var.tags, {
    Environment = each.key
  })
}

# Routing Intent for secure hubs - Forces traffic through firewall
resource "azapi_resource" "routing_intent" {
  for_each = { 
    for key, hub in var.virtual_hubs : key => hub 
    if hub.enable_routing_intent 
  }
  
  type      = "Microsoft.Network/virtualHubs/routingIntent@2023-11-01"
  parent_id = azurerm_virtual_hub.vhub[each.key].id
  name      = "routing-intent-${each.key}"
  
  body = {
    properties = {
      routingPolicies = [
        {
          name         = "InternetTraffic"
          destinations = ["Internet"]
          nextHop      = azurerm_firewall.hub_firewall[each.key].id
        },
        {
          name         = "PrivateTraffic"
          destinations = ["PrivateTraffic"]
          nextHop      = azurerm_firewall.hub_firewall[each.key].id
        }
      ]
    }
  }
  
  depends_on = [
    azurerm_firewall.hub_firewall,
    azurerm_virtual_hub.vhub
  ]
}

# VNet connections to Virtual Hubs
resource "azurerm_virtual_hub_connection" "vnet_connections" {
  for_each = var.vnet_connections
  
  name                      = "conn-${each.key}-${var.suffix}"
  virtual_hub_id            = azurerm_virtual_hub.vhub[each.value.hub_key].id
  remote_virtual_network_id = each.value.vnet_id
  
  # Enable internet security through the hub firewall
  internet_security_enabled = each.value.internet_security_enabled
  
  # Routing configuration
  routing {
    associated_route_table_id = each.value.associated_route_table_id
    
    dynamic "propagated_route_table" {
      for_each = each.value.propagated_route_tables
      content {
        labels          = propagated_route_table.value.labels
        route_table_ids = propagated_route_table.value.route_table_ids
      }
    }
    
    dynamic "static_vnet_route" {
      for_each = each.value.static_routes
      content {
        name                = static_vnet_route.value.name
        address_prefixes    = static_vnet_route.value.address_prefixes
        next_hop_ip_address = static_vnet_route.value.next_hop_ip_address
      }
    }
  }
  
  depends_on = [azurerm_virtual_hub.vhub]
}

# Custom route tables for advanced routing scenarios
resource "azurerm_virtual_hub_route_table" "custom_route_tables" {
  for_each = var.custom_route_tables
  
  name           = each.key
  virtual_hub_id = azurerm_virtual_hub.vhub[each.value.hub_key].id
  labels         = each.value.labels
  
  dynamic "route" {
    for_each = each.value.routes
    content {
      name              = route.value.name
      destinations_type = route.value.destinations_type
      destinations      = route.value.destinations
      next_hop_type     = route.value.next_hop_type
      next_hop          = route.value.next_hop
    }
  }
  
  depends_on = [azurerm_virtual_hub.vhub]
}

# ================================================================
# AZURE VIRTUAL NETWORK MANAGER INTEGRATION - HYBRID APPROACH
# ================================================================
# Existing prod/nonprod isolation (static) + Intent layer test VM rules (configurable)

# Existing Network Groups for prod/nonprod isolation (keep as-is)
resource "azurerm_network_manager_network_group" "prod_network_group" {
  count = var.enable_network_manager_integration ? 1 : 0
  
  name               = "prod-hubs-network-group-${var.suffix}"
  network_manager_id = var.network_manager_config.network_manager_id
  
  description = "Network group for Production Virtual WAN Hubs"
}

resource "azurerm_network_manager_network_group" "nonprod_network_group" {
  count = var.enable_network_manager_integration ? 1 : 0
  
  name               = "nonprod-hubs-network-group-${var.suffix}"
  network_manager_id = var.network_manager_config.network_manager_id
  
  description = "Network group for Non-Production Virtual WAN Hubs"
}

# Use the tenant's security admin configuration instead of creating our own
# This avoids the "shouldn't contain more than 1 security Configuration" error

# Existing prod/nonprod isolation rule collection (static)
resource "azurerm_network_manager_admin_rule_collection" "isolation_rules" {
  count = var.enable_network_manager_integration && var.network_manager_config.security_admin_configuration_id != null ? 1 : 0
  
  name                            = "prod-nonprod-isolation-${var.suffix}"
  security_admin_configuration_id = var.network_manager_config.security_admin_configuration_id
  
  network_group_ids = [
    azurerm_network_manager_network_group.prod_network_group[0].id,
    azurerm_network_manager_network_group.nonprod_network_group[0].id
  ]
  
  description = "Rules for Production to Non-Production isolation"
}

# Existing isolation rules (static)
resource "azurerm_network_manager_admin_rule" "block_prod_to_nonprod" {
  count = var.enable_network_manager_integration && var.network_manager_config.security_admin_configuration_id != null ? 1 : 0
  
  name                     = "deny-prod-to-nonprod-${var.suffix}"
  admin_rule_collection_id = azurerm_network_manager_admin_rule_collection.isolation_rules[0].id
  
  description = "Block all traffic from Production to Non-Production environments at network edge"
  action      = "Deny"
  direction   = "Outbound"
  priority    = 100
  protocol    = "Any"
  
  source {
    address_prefix      = "*"
    address_prefix_type = "IPPrefix"
  }
  
  destination {
    address_prefix      = "*"
    address_prefix_type = "IPPrefix"
  }
  
  source_port_ranges      = ["0-65535"]
  destination_port_ranges = ["0-65535"]
}

resource "azurerm_network_manager_admin_rule" "block_nonprod_to_prod" {
  count = var.enable_network_manager_integration && var.network_manager_config.security_admin_configuration_id != null ? 1 : 0
  
  name                     = "deny-nonprod-to-prod-${var.suffix}"
  admin_rule_collection_id = azurerm_network_manager_admin_rule_collection.isolation_rules[0].id
  
  description = "Block all traffic from Non-Production to Production environments at network edge"
  action      = "Deny"
  direction   = "Outbound"
  priority    = 101
  protocol    = "Any"
  
  source {
    address_prefix      = "*"
    address_prefix_type = "IPPrefix"
  }
  
  destination {
    address_prefix      = "*"
    address_prefix_type = "IPPrefix"
  }
  
  source_port_ranges      = ["0-65535"]
  destination_port_ranges = ["0-65535"]
}

# ================================================================
# INTENT LAYER TEST VM CONNECTIVITY RULES - CONFIGURABLE FROM VARS.TFVARS
# ================================================================
# Test VM rules leverage existing nonprod network group instead of creating separate groups
# Note: Disabled separate test-vm-connectivity-rules collection since all rules are now defined in intent-layer-rules

# Test VM Rule Collection from Intent Layer - uses existing nonprod network group
# Completely disabled since test VM rules are now in the intent layer rules collection
resource "azurerm_network_manager_admin_rule_collection" "test_vm_connectivity_rules" {
  # Multiple conditions to ensure this collection is never created:
  # 1. Hard-coded count = 0
  # 2. Conditional expression that evaluates to false
  count = 0 * (var.enable_network_manager_integration && var.deploy_test_vms && var.intent_layer.enabled ? 0 : 0)
  
  name                            = "test-vm-connectivity-rules-${var.suffix}"
  security_admin_configuration_id = var.network_manager_config.security_admin_configuration_id
  
  # Use existing nonprod network group for test VM rules
  network_group_ids = [
    azurerm_network_manager_network_group.nonprod_network_group[0].id
  ]
  
  description = "Rules to allow test VM connectivity for Virtual WAN testing (TiP - Test Infrastructure Provisioning) - configured via Intent Layer - uses existing nonprod network group"
}

# Dynamic Test VM Security Admin Rules from Intent Layer Configuration
# No longer needed since test VM rules are now in the intent layer rules collection
resource "azurerm_network_manager_admin_rule" "intent_layer_test_vm_rules" {
  # Set for_each to empty map to disable creation of these rules since they exist in intent-layer-rules
  for_each = {}
  
  name                     = "${lookup(each.value, "name", "placeholder")}-${var.suffix}"
  # Reference index 0 in a count that's now 0 would cause an error, so we use a ternary to avoid it
  admin_rule_collection_id = length(azurerm_network_manager_admin_rule_collection.test_vm_connectivity_rules) > 0 ? azurerm_network_manager_admin_rule_collection.test_vm_connectivity_rules[0].id : ""
  
  description = lookup(each.value, "description", "")
  action      = lookup(each.value, "action", "Allow")
  direction   = lookup(each.value, "direction", "Inbound")
  priority    = lookup(each.value, "priority", 100)
  protocol    = lookup(each.value, "protocol", "Tcp")
  
  # Placeholder source config (never used since for_each is empty)
  source {
    address_prefix_type = "IPPrefix"
    address_prefix      = "*"
  }
  
  # Placeholder destination config (never used since for_each is empty)
  destination {
    address_prefix_type = "IPPrefix"
    address_prefix      = "*"
  }
  
  # Placeholder port config (never used since for_each is empty)
  source_port_ranges      = ["*"]
  destination_port_ranges = ["*"]
}
