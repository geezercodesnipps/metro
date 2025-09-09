resource "azapi_resource" "nsg_dns_resolver_inbound" {
  type      = "Microsoft.Network/networkSecurityGroups@2024-01-01"
  parent_id = azapi_resource.resource_group_network_hub.id
  name      = "dns-resolver-inbound-subnet-nsg-${local.suffix}"
  location  = var.location
  tags      = var.tags

  response_export_values    = ["*"]
  schema_validation_enabled = true
  locks                     = []
  ignore_casing             = false
  ignore_missing_property   = false
}

resource "azapi_resource" "allow_tcp_53_inbound_dns_inbound" {
  type      = "Microsoft.Network/networkSecurityGroups/securityRules@2024-01-01"
  parent_id = azapi_resource.nsg_dns_resolver_inbound.id
  name      = "AllowDnsTcpInbound"

  body = {
    properties = {
      priority                 = 1000
      direction                = "Inbound"
      access                   = "Allow"
      protocol                 = "Tcp"
      sourcePortRange          = "*"
      destinationPortRange     = "53"
      sourceAddressPrefix      = "VirtualNetwork"
      destinationAddressPrefix = "*"
    }
  }

  response_export_values    = ["*"]
  schema_validation_enabled = true
  locks                     = []
  ignore_casing             = false
  ignore_missing_property   = false
}

resource "azapi_resource" "allow_udp_53_inbound_dns_inbound" {
  type      = "Microsoft.Network/networkSecurityGroups/securityRules@2024-01-01"
  parent_id = azapi_resource.nsg_dns_resolver_inbound.id
  name      = "AllowDnsUdpInbound"

  body = {
    properties = {
      priority                 = 1010
      direction                = "Inbound"
      access                   = "Allow"
      protocol                 = "Udp"
      sourcePortRange          = "*"
      destinationPortRange     = "53"
      sourceAddressPrefix      = "VirtualNetwork"
      destinationAddressPrefix = "*"
    }
  }

  response_export_values    = ["*"]
  schema_validation_enabled = true
  locks                     = []
  ignore_casing             = false
  ignore_missing_property   = false
}

resource "azapi_resource" "deny_all_inbound_dns_inbound" {
  type      = "Microsoft.Network/networkSecurityGroups/securityRules@2024-01-01"
  parent_id = azapi_resource.nsg_dns_resolver_inbound.id
  name      = "DenyAllInbound"

  body = {
    properties = {
      priority                 = 1020
      direction                = "Inbound"
      access                   = "Deny"
      protocol                 = "*"
      sourcePortRange          = "*"
      destinationPortRange     = "*"
      sourceAddressPrefix      = "*"
      destinationAddressPrefix = "*"
    }
  }

  response_export_values    = ["*"]
  schema_validation_enabled = true
  locks                     = []
  ignore_casing             = false
  ignore_missing_property   = false
}

resource "azapi_resource" "deny_all_outbound_dns_inbound" {
  type      = "Microsoft.Network/networkSecurityGroups/securityRules@2024-01-01"
  parent_id = azapi_resource.nsg_dns_resolver_inbound.id
  name      = "DenyAllOutbound"

  body = {
    properties = {
      priority                 = 1000
      direction                = "Outbound"
      access                   = "Deny"
      protocol                 = "*"
      sourcePortRange          = "*"
      destinationPortRange     = "*"
      sourceAddressPrefix      = "*"
      destinationAddressPrefix = "*"
    }
  }

  response_export_values    = ["*"]
  schema_validation_enabled = true
  locks                     = []
  ignore_casing             = false
  ignore_missing_property   = false
}

resource "azapi_resource" "nsg_dns_resolver_outbound" {
  type      = "Microsoft.Network/networkSecurityGroups@2024-01-01"
  parent_id = azapi_resource.resource_group_network_hub.id
  name      = "dns-resolver-outbound-subnet-nsg-${local.suffix}"
  location  = var.location
  tags      = var.tags

  response_export_values    = ["*"]
  schema_validation_enabled = true
  locks                     = []
  ignore_casing             = false
  ignore_missing_property   = false
}

resource "azapi_resource" "allow_tcp_53_inbound_dns_outbound" {
  type      = "Microsoft.Network/networkSecurityGroups/securityRules@2024-01-01"
  parent_id = azapi_resource.nsg_dns_resolver_outbound.id
  name      = "AllowDnsTcpInbound"

  body = {
    properties = {
      priority                 = 1000
      direction                = "Inbound"
      access                   = "Allow"
      protocol                 = "Tcp"
      sourcePortRange          = "*"
      destinationPortRange     = "53"
      sourceAddressPrefix      = "VirtualNetwork"
      destinationAddressPrefix = "*"
    }
  }

  response_export_values    = ["*"]
  schema_validation_enabled = true
  locks                     = []
  ignore_casing             = false
  ignore_missing_property   = false
}

resource "azapi_resource" "allow_udp_53_inbound_dns_outbound" {
  type      = "Microsoft.Network/networkSecurityGroups/securityRules@2024-01-01"
  parent_id = azapi_resource.nsg_dns_resolver_outbound.id
  name      = "AllowDnsUdpInbound"

  body = {
    properties = {
      priority                 = 1010
      direction                = "Inbound"
      access                   = "Allow"
      protocol                 = "Udp"
      sourcePortRange          = "*"
      destinationPortRange     = "53"
      sourceAddressPrefix      = "VirtualNetwork"
      destinationAddressPrefix = "*"
    }
  }

  response_export_values    = ["*"]
  schema_validation_enabled = true
  locks                     = []
  ignore_casing             = false
  ignore_missing_property   = false
}

resource "azapi_resource" "deny_all_inbound_dns_outbound" {
  type      = "Microsoft.Network/networkSecurityGroups/securityRules@2024-01-01"
  parent_id = azapi_resource.nsg_dns_resolver_outbound.id
  name      = "DenyAllInbound"

  body = {
    properties = {
      priority                 = 1020
      direction                = "Inbound"
      access                   = "Deny"
      protocol                 = "*"
      sourcePortRange          = "*"
      destinationPortRange     = "*"
      sourceAddressPrefix      = "*"
      destinationAddressPrefix = "*"
    }
  }

  response_export_values    = ["*"]
  schema_validation_enabled = true
  locks                     = []
  ignore_casing             = false
  ignore_missing_property   = false
}

resource "azapi_resource" "allow_tcp_53_outbound_dns_outbound" {
  type      = "Microsoft.Network/networkSecurityGroups/securityRules@2024-01-01"
  parent_id = azapi_resource.nsg_dns_resolver_outbound.id
  name      = "AllowDnsTcpOutbound"

  body = {
    properties = {
      priority                 = 1000
      direction                = "Outbound"
      access                   = "Allow"
      protocol                 = "Tcp"
      sourcePortRange          = "*"
      destinationPortRange     = "53"
      sourceAddressPrefix      = "*"
      destinationAddressPrefix = "VirtualNetwork"
    }
  }

  response_export_values    = ["*"]
  schema_validation_enabled = true
  locks                     = []
  ignore_casing             = false
  ignore_missing_property   = false
}

resource "azapi_resource" "allow_udp_53_outbound_dns_outbound" {
  type      = "Microsoft.Network/networkSecurityGroups/securityRules@2024-01-01"
  parent_id = azapi_resource.nsg_dns_resolver_outbound.id
  name      = "AllowDnsUdpOutbound"

  body = {
    properties = {
      priority                 = 1010
      direction                = "Outbound"
      access                   = "Allow"
      protocol                 = "Udp"
      sourcePortRange          = "*"
      destinationPortRange     = "53"
      sourceAddressPrefix      = "*"
      destinationAddressPrefix = "VirtualNetwork"
    }
  }

  response_export_values    = ["*"]
  schema_validation_enabled = true
  locks                     = []
  ignore_casing             = false
  ignore_missing_property   = false
}

resource "azapi_resource" "deny_all_outbound_dns_outbound" {
  type      = "Microsoft.Network/networkSecurityGroups/securityRules@2024-01-01"
  parent_id = azapi_resource.nsg_dns_resolver_outbound.id
  name      = "DenyAllOutbound"

  body = {
    properties = {
      priority                 = 1020
      direction                = "Outbound"
      access                   = "Deny"
      protocol                 = "*"
      sourcePortRange          = "*"
      destinationPortRange     = "*"
      sourceAddressPrefix      = "*"
      destinationAddressPrefix = "*"
    }
  }

  response_export_values    = ["*"]
  schema_validation_enabled = true
  locks                     = []
  ignore_casing             = false
  ignore_missing_property   = false
}
