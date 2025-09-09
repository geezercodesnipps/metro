resource "azapi_resource" "subnet_ergw" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-01-01"
  parent_id = azapi_resource.virtual_network_hub.id
  name      = "GatewaySubnet"

  body = {
    properties = {
      addressPrefix = var.address_space_gateway_subnet
      routeTable = {
        id = azapi_resource.route_table_gw_subnet.id
      }
    }
  }

  response_export_values    = ["*"]
  schema_validation_enabled = true
  locks                     = []
  ignore_casing             = false
  ignore_missing_property   = false
}

resource "azapi_resource" "subnet_azfw_management" {
  count     = var.address_space_azfw_management_subnet != "" ? 1 : 0
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-01-01"
  parent_id = azapi_resource.virtual_network_hub.id
  name      = "AzureFirewallManagementSubnet"

  body = {
    properties = {
      addressPrefix = var.address_space_azfw_management_subnet
    }
  }

  response_export_values    = ["*"]
  schema_validation_enabled = true
  locks                     = []
  ignore_casing             = false
  ignore_missing_property   = false
  depends_on = [
    azapi_resource.subnet_azfw,
    azapi_resource.subnet_ergw,  # Wait for gateway subnet operations to complete
    azapi_resource.subnet_dns_inbound,
    azapi_resource.subnet_dns_outbound
  ]
}

resource "azapi_resource" "subnet_azfw" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-01-01"
  parent_id = azapi_resource.virtual_network_hub.id
  name      = "AzureFirewallSubnet"

  body = {
    properties = {
      addressPrefix = var.address_space_azfw_subnet
      routeTable = {
        id = azapi_resource.route_table_azfw_subnet.id
      }
    }
  }

  response_export_values    = ["*"]
  schema_validation_enabled = true
  locks                     = []
  ignore_casing             = false
  ignore_missing_property   = false
  depends_on = [
    azapi_resource.subnet_ergw,
    time_sleep.sleep_route_table_azfw_subnet_default_route
  ]
}

resource "azapi_resource" "subnet_dns_inbound" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-01-01"
  parent_id = azapi_resource.virtual_network_hub.id
  name      = "DnsResolverInboundSubnet"

  body = {
    properties = {
      addressPrefix = var.address_space_dns_inbound_subnet
      networkSecurityGroup = {
        id = azapi_resource.nsg_dns_resolver_inbound.id
      }
      delegations = [
        {
          name = "Microsoft.Network.dnsResolvers"
          properties = {
            serviceName = "Microsoft.Network/dnsResolvers"
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
  depends_on = [
    azapi_resource.subnet_azfw,
  ]
}

resource "azapi_resource" "subnet_dns_outbound" {
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-01-01"
  parent_id = azapi_resource.virtual_network_hub.id
  name      = "DnsResolverOutboundSubnet"

  body = {
    properties = {
      addressPrefix = var.address_space_dns_outbound_subnet
      networkSecurityGroup = {
        id = azapi_resource.nsg_dns_resolver_outbound.id
      }
      delegations = [
        {
          name = "Microsoft.Network.dnsResolvers"
          properties = {
            serviceName = "Microsoft.Network/dnsResolvers"
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
  depends_on = [
    azapi_resource.subnet_dns_inbound,
  ]
}
