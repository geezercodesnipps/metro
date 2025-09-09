resource "azapi_resource" "virtual_network_hub" {
  type      = "Microsoft.Network/virtualNetworks@2024-01-01"
  parent_id = azapi_resource.resource_group_network_hub.id
  name      = "${local.hub_prefix}-${local.suffix}"
  location  = var.location
  tags      = var.tags

  body = {
    properties = {
      addressSpace = {
        addressPrefixes = [
          var.address_space_network_hub
        ]
      }
    }
  }

  response_export_values    = ["*"]
  schema_validation_enabled = true
  locks                     = []
  ignore_casing             = false
  ignore_missing_property   = false
}
