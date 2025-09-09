resource "azapi_resource" "private_dns_resolver" {
  type      = "Microsoft.Network/dnsResolvers@2022-07-01"
  parent_id = azapi_resource.resource_group_network_hub.id
  name      = "dns-resolver-${local.suffix}"
  location  = var.location
  tags      = var.tags

  body = {
    properties = {
      virtualNetwork = {
        id = azapi_resource.virtual_network_hub.id
      }
    }
  }

  response_export_values    = ["*"]
  schema_validation_enabled = true
  locks                     = []
  ignore_casing             = false
  ignore_missing_property   = false
}

resource "azapi_resource" "private_dns_resolver_inbound" {
  type      = "Microsoft.Network/dnsResolvers/inboundEndpoints@2022-07-01"
  parent_id = azapi_resource.private_dns_resolver.id
  name      = "dns-resolver-inbound-endpoint-${local.suffix}"
  location  = var.location
  tags      = var.tags

  body = {
    properties = {
      ipConfigurations = [
        {
          privateIpAllocationMethod = "Dynamic"
          subnet = {
            id = azapi_resource.subnet_dns_inbound.id
          }
        }
      ]
    }
  }

  response_export_values    = ["*"]
  schema_validation_enabled = true
  locks                     = []
  ignore_casing             = false
  ignore_missing_property   = false
}

resource "azapi_resource" "private_dns_resolver_outbound" {
  type      = "Microsoft.Network/dnsResolvers/outboundEndpoints@2022-07-01"
  parent_id = azapi_resource.private_dns_resolver.id
  name      = "dns-resolver-outbound-endpoint-${local.suffix}"
  location  = var.location
  tags      = var.tags

  body = {
    properties = {
      subnet = {
        id = azapi_resource.subnet_dns_outbound.id
      }
    }
  }

  response_export_values    = ["*"]
  schema_validation_enabled = true
  locks                     = []
  ignore_casing             = false
  ignore_missing_property   = false
}
