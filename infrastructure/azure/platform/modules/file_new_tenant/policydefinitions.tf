resource "azurerm_policy_definition" "network_manager_global_hub_vnets_policy_definition" {
  for_each            = toset(var.environments)
  name                = "network-manager-global-hub-vnets-policy-${each.value}"
  management_group_id = azurerm_management_group.management_group_root.id
  policy_type         = "Custom"
  mode                = "Microsoft.Network.Data"
  display_name        = "Policy Definition for global hub VNets network group (${each.value})"

  metadata = <<METADATA
    {
      "category": "Azure Virtual Network Manager",
      "version": "1.0.0"
    }
  METADATA

  policy_rule = <<POLICY_RULE
    {
      "if": {
        "allOf": [
          {
              "field": "type",
              "equals": "Microsoft.Network/virtualNetworks"
          },
          {
            "allOf": [
              {
              "field": "Name",
              "contains": "${local.hub_prefix}-${local.suffix}"
              },
              {
              "field": "Name",
              "contains": "${each.value}"
              }
            ]
          }
        ]
      },
      "then": {
        "effect": "addToNetworkGroup",
        "details": {
          "networkGroupId": "${azurerm_network_manager_network_group.global_hub_vnets[each.key].id}"
        }
      }
    }
  POLICY_RULE
}

resource "azurerm_policy_definition" "network_manager_spoke_vnets_policy_definition" {
  name                = "network-manager-spoke-vnets-policy"
  management_group_id = azurerm_management_group.management_group_root.id
  policy_type         = "Custom"
  mode                = "Microsoft.Network.Data"
  display_name        = "Policy definition for spokes VNets network group (${local.suffix})"

  metadata = <<METADATA
    {
      "category": "Azure Virtual Network Manager",
      "version": "1.0.0"
    }
  METADATA

  policy_rule = <<POLICY_RULE
    {
      "if": {
        "allOf": [
          {
              "field": "type",
              "equals": "Microsoft.Network/virtualNetworks"
          },
          {
            "allOf": [
              {
              "field": "Name",
              "contains": "${var.spoke_prefix}"
              },
              {
              "field": "Name",
              "contains": "${local.suffix}"
              }
            ]
          }
        ]
      },
      "then": {
        "effect": "addToNetworkGroup",
        "details": {
          "networkGroupId": "${azurerm_network_manager_network_group.network_manager_network_group_spoke_vnets.id}"
        }
      }
    }
  POLICY_RULE
}
