resource "azurerm_policy_definition" "network_manager_regional_spoke_vnets_policy_definition" {
  name                = "network-manager-spoke-vnets-policy-${local.suffix}"
  management_group_id = var.management_group_id
  policy_type         = "Custom"
  mode                = "Microsoft.Network.Data"
  display_name        = "Policy definition for regional spoke VNets network group (${local.suffix})"
  description         = "This policy definition ensures regional spokes are added to their corresponding Network Manager network group"

  metadata = <<METADATA
    {
      "category": "Azure Virtual Network Manager"
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
              "contains": "${local.spoke_prefix}"
              },
              {
              "field": "Name",
              "contains": "${local.suffix}"
              },
              {
              "field": "location",
              "contains": "${var.location}"
              }
            ]
          }
        ]
      },
      "then": {
        "effect": "addToNetworkGroup",
        "details": {
          "networkGroupId": "${azurerm_network_manager_network_group.regional_spoke_vnets.id}"
        }
      }
    }
  POLICY_RULE
}
