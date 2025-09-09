# ExpressRoute Gateway resource
resource "azapi_resource" "ergw" {
  type      = "Microsoft.Network/virtualNetworkGateways@2024-01-01"
  parent_id = azapi_resource.resource_group_network_hub.id
  name      = "ergw-${local.suffix}"
  location  = var.location
  tags      = var.tags

  body = {
    properties = {
      gatewayType = "ExpressRoute"
      ipConfigurations = [
        {
          name = "vnetGatewayConfig"
          properties = {
            publicIPAddress = {
              id = azapi_resource.public_ip_ergw.id
            }
            subnet = {
              id = azapi_resource.subnet_ergw.id
            }
          }
        },
      ]
      sku = {
        name = var.ergw_sku
        tier = var.ergw_sku
      }
    }
  }

  # Use lifecycle to ignore changes to ipConfigurations since Azure API is inconsistent
  lifecycle {
    ignore_changes = [
      body["properties"]["ipConfigurations"]
    ]
  }

  timeouts {
    create = "60m"
  }

  response_export_values    = ["*"]
  schema_validation_enabled = true
  locks                     = []
  ignore_casing             = false
  ignore_missing_property   = true

  depends_on = [
    azapi_resource.route_table_gw_subnet,
    azapi_resource.subnet_dns_outbound,
    azapi_resource.firewall,
  ]
}
data "azapi_resource" "ergw_deployed" {
  type      = "Microsoft.Network/virtualNetworkGateways@2024-01-01"
  parent_id = azapi_resource.resource_group_network_hub.id
  name      = "ergw-${local.suffix}"

  depends_on = [azapi_resource.ergw]
}

locals {
  deployed_ergw_public_ip_id = try(
    data.azapi_resource.ergw_deployed.output.properties.ipConfigurations[0].properties.publicIPAddress.id,
    null
  )
  
  ergw_ip_config_debug = {
    has_ip_config = can(data.azapi_resource.ergw_deployed.output.properties.ipConfigurations[0])
    public_ip_id = local.deployed_ergw_public_ip_id
    azure_returns_incomplete_config = local.deployed_ergw_public_ip_id == null
  }
}

# Output for monitoring Azure API consistency
output "ergw_state_debug" {
  description = "Debug information about ExpressRoute Gateway state consistency"
  value = local.ergw_ip_config_debug
}
