resource "azapi_resource" "route_table_gw_subnet" {
  type      = "Microsoft.Network/routeTables@2024-01-01"
  parent_id = azapi_resource.resource_group_network_hub.id
  name      = "ergw-subnet-udr-${local.suffix}"
  location  = var.location
  tags      = var.tags

  body = {
    properties = {
      disableBgpRoutePropagation = false
    }
  }

  response_export_values    = ["*"]
  schema_validation_enabled = true
  locks                     = []
  ignore_casing             = false
  ignore_missing_property   = false
}

resource "azapi_resource" "route_table_azfw_subnet" {
  type      = "Microsoft.Network/routeTables@2024-01-01"
  parent_id = azapi_resource.resource_group_network_hub.id
  name      = "azfw-subnet-udr-${local.suffix}"
  location  = var.location
  tags      = var.tags

  body = {
    properties = {
      disableBgpRoutePropagation = false
    }
  }

  response_export_values    = ["*"]
  schema_validation_enabled = true
  locks                     = []
  ignore_casing             = false
  ignore_missing_property   = false
}

resource "azapi_resource" "route_table_azfw_subnet_default_route" {
  type      = "Microsoft.Network/routeTables/routes@2024-01-01"
  parent_id = azapi_resource.route_table_azfw_subnet.id
  name      = "defaultRoute"

  body = {
    properties = {
      addressPrefix = "0.0.0.0/0"
      nextHopType   = "Internet"
    }
  }

  response_export_values    = ["*"]
  schema_validation_enabled = true
  locks                     = []
  ignore_casing             = false
  ignore_missing_property   = false
}

#Introduce a 10s delay after default route creation to avoid race condition when associating with AzureFirewallSubnet
resource "time_sleep" "sleep_route_table_azfw_subnet_default_route" {
  create_duration = "10s"

  depends_on = [
    azapi_resource.route_table_azfw_subnet_default_route
  ]
}
