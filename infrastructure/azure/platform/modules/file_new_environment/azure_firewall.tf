resource "azapi_resource" "firewall" {
  type      = "Microsoft.Network/azureFirewalls@2024-01-01"
  parent_id = azapi_resource.resource_group_network_hub.id
  name      = "azfw-${local.suffix}"
  location  = var.location
  tags      = var.tags

  # Note: Firewall will be deployed in running state initially
  # Run the post-deployment script to stop the firewall for cost savings:
  # az network firewall deallocate --name azfw-${local.suffix} --resource-group ${resource_group_name}
  body = {
    properties = {
      ipConfigurations = [
        {
          name = "azfw-ipconfig"
          properties = {
            publicIPAddress = {
              id = azapi_resource.public_ip_azfw.id
            }
            subnet = {
              id = azapi_resource.subnet_azfw.id
            }
          }
        },
      ]
      sku = {
        name = "AZFW_VNet"
        tier = var.azfw_sku
      }
      # Management configuration is required for Basic SKU
      managementIpConfiguration = var.azfw_sku == "Basic" ? {
        name = "azfw-mgmt-ipconfig"
        properties = {
          publicIPAddress = {
            id = azapi_resource.public_ip_azfw_management[0].id
          }
          subnet = {
            id = azapi_resource.subnet_azfw_management[0].id
          }
        }
      } : null
    }
    zones = ["1", "2", "3"]
  }

  timeouts {
    create = "60m"
  }

  depends_on = [
    azapi_resource.route_table_azfw_subnet
  ]

  response_export_values    = ["*"]
  schema_validation_enabled = true
  locks                     = []
  ignore_casing             = false
  ignore_missing_property   = false
}
