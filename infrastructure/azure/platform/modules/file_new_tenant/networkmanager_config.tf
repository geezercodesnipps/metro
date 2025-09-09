# Create a network group
resource "azurerm_network_manager_network_group" "global_hub_vnets" {
  provider = azurerm.network

  for_each = toset(var.environments)

  name               = "global-hubs-network-group-${local.suffix}-${each.value}"
  network_manager_id = azurerm_network_manager.network_manager.id
}

# Create a connectivity configuration
resource "azurerm_network_manager_connectivity_configuration" "global_hub_vnets_mesh" {
  provider = azurerm.network

  for_each = toset(var.environments)

  name               = "global-hub-vnets-mesh-connectivity-configuration-${local.suffix}-${each.value}"
  network_manager_id = azurerm_network_manager.network_manager.id

  description                     = "Global Hub VNets mesh connectivity configuration (${local.suffix})"
  connectivity_topology           = "Mesh"
  delete_existing_peering_enabled = true
  global_mesh_enabled             = true

  applies_to_group {
    group_connectivity = "DirectlyConnected"
    network_group_id   = azurerm_network_manager_network_group.global_hub_vnets[each.key].id
    use_hub_gateway    = false
  }
}

# Create network group for spoke vnets
resource "azurerm_network_manager_network_group" "network_manager_network_group_spoke_vnets" {
  provider = azurerm.network

  name               = "spoke-vnets-network-group-${local.suffix}"
  network_manager_id = azurerm_network_manager.network_manager.id

  description = "Network Group for spoke VNets (${local.suffix})"
}

# Create security admin configuration for spoke vnets - Only when TiP is deployed
resource "azurerm_network_manager_security_admin_configuration" "network_manager_security_admin_configuration_spoke_vnets" {
  provider = azurerm.network
  count    = var.deploy_test_vms ? 1 : 0

  name               = "spoke-vnets-security-admin-rules-${local.suffix}"
  network_manager_id = azurerm_network_manager.network_manager.id

  apply_on_network_intent_policy_based_services = [
    "AllowRulesOnly"
  ]
  description = "Security Admin Configuration for spoke VNets (${local.suffix})"
}

# Create rule collection for spoke vnets - Only when TiP is deployed
resource "azurerm_network_manager_admin_rule_collection" "network_manager_admin_rule_collection" {
  provider = azurerm.network
  count    = var.deploy_test_vms ? 1 : 0

  name                            = "spoke-vnets-admin-rule-collection-${local.suffix}"
  security_admin_configuration_id = azurerm_network_manager_security_admin_configuration.network_manager_security_admin_configuration_spoke_vnets[0].id

  description = "Network Manager Admin Rules Collection for spoke VNets"
  network_group_ids = [
    azurerm_network_manager_network_group.network_manager_network_group_spoke_vnets.id
  ]
}

# Create rules for spoke vnets - Only when TiP is deployed
resource "azurerm_network_manager_admin_rule" "network_manager_admin_rule_deny_ssh_inbound" {
  provider = azurerm.network
  count    = var.deploy_test_vms ? 1 : 0

  name                     = "deny-ssh-inbound-${local.suffix}"
  admin_rule_collection_id = azurerm_network_manager_admin_rule_collection.network_manager_admin_rule_collection[0].id

  description = "Deny SSH inbound connections from the internet"
  action      = "Deny"
  direction   = "Inbound"
  destination {
    address_prefix      = "*"
    address_prefix_type = "IPPrefix"
  }
  destination_port_ranges = [
    "22"
  ]
  priority = 500
  protocol = "Tcp"
  source {
    address_prefix      = "Internet"
    address_prefix_type = "ServiceTag"
  }
  source_port_ranges = [
    "0-65535"
  ]

  timeouts {
    delete = "60m"
  }
}

# Create rules for spoke vnets - Only when TiP is deployed
resource "azurerm_network_manager_admin_rule" "network_manager_admin_rule_deny_rdp_inbound" {
  provider = azurerm.network
  count    = var.deploy_test_vms ? 1 : 0

  name                     = "deny-rdp-inbound-${local.suffix}"
  admin_rule_collection_id = azurerm_network_manager_admin_rule_collection.network_manager_admin_rule_collection[0].id

  description = "Deny RDP inbound connections from the internet"
  action      = "Deny"
  direction   = "Inbound"
  destination {
    address_prefix      = "*"
    address_prefix_type = "IPPrefix"
  }
  destination_port_ranges = [
    "3389"
  ]
  priority = 510
  protocol = "Tcp"
  source {
    address_prefix      = "Internet"
    address_prefix_type = "ServiceTag"
  }
  source_port_ranges = [
    "0-65535"
  ]

  timeouts {
    delete = "60m"
  }
}

resource "time_sleep" "sleep_network_manager_security_admin_configurations" {
  count           = var.deploy_test_vms ? 1 : 0
  create_duration = "1s"
  triggers        = {}

  depends_on = [
    azurerm_network_manager_admin_rule_collection.network_manager_admin_rule_collection,
    azurerm_network_manager_admin_rule.network_manager_admin_rule_deny_ssh_inbound,
    azurerm_network_manager_admin_rule.network_manager_admin_rule_deny_rdp_inbound,
  ]
}
