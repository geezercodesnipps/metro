resource "azapi_resource" "public_ip_ergw" {
  type      = "Microsoft.Network/publicIPAddresses@2024-01-01"
  parent_id = azapi_resource.resource_group_network_hub.id
  name      = "ergw-pip-${local.suffix}"
  location  = var.location
  tags      = var.tags

  body = {
    properties = {
      publicIPAllocationMethod = "Static"
    }
    sku = {
      name = "Standard"
    }
  }

  response_export_values    = ["*"]
  schema_validation_enabled = true
  locks                     = []
  ignore_casing             = false
  ignore_missing_property   = false
}

resource "azapi_resource" "public_ip_azfw" {
  type      = "Microsoft.Network/publicIPAddresses@2024-01-01"
  parent_id = azapi_resource.resource_group_network_hub.id
  name      = "azfw-pip-${local.suffix}"
  location  = var.location
  tags      = var.tags

  body = {
    properties = {
      publicIPAllocationMethod = "Static"
    }
    sku = {
      name = "Standard"
    }
    zones = ["1", "2", "3"]
  }

  response_export_values    = ["*"]
  schema_validation_enabled = true
  locks                     = []
  ignore_casing             = false
  ignore_missing_property   = false
}

resource "azapi_resource" "public_ip_azfw_management" {
  count     = var.address_space_azfw_management_subnet != "" ? 1 : 0
  type      = "Microsoft.Network/publicIPAddresses@2024-01-01"
  parent_id = azapi_resource.resource_group_network_hub.id
  name      = "azfw-mgmt-pip-${local.suffix}"
  location  = var.location
  tags      = var.tags

  body = {
    properties = {
      publicIPAllocationMethod = "Static"
    }
    sku = {
      name = "Standard"
    }
    zones = ["1", "2", "3"]
  }

  response_export_values    = ["*"]
  schema_validation_enabled = true
  locks                     = []
  ignore_casing             = false
  ignore_missing_property   = false
}
