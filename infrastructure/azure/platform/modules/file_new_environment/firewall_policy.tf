resource "azapi_resource" "firewall_policy" {
  type      = "Microsoft.Network/firewallPolicies@2024-01-01"
  parent_id = azapi_resource.resource_group_network_hub.id
  name      = "azfw-policy-${local.suffix}"
  location  = var.location
  tags      = var.tags

  body = {
    properties = {
      sku = {
        tier = var.azfw_sku
      }
    }
  }

  response_export_values    = ["*"]
  schema_validation_enabled = true
  locks                     = []
  ignore_casing             = false
  ignore_missing_property   = false
}
