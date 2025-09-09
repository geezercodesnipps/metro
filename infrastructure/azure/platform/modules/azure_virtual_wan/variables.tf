# Variables for Azure Virtual WAN Module

# General variables
variable "suffix" {
  description = "Suffix for resource names"
  type        = string
  
  validation {
    condition     = length(var.suffix) >= 2 && length(var.suffix) <= 8
    error_message = "Suffix must be between 2 and 8 characters."
  }
}

variable "resource_group_name" {
  description = "Name of the resource group for Virtual WAN resources"
  type        = string
}

variable "location" {
  description = "Primary Azure region for the Virtual WAN resource"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Virtual WAN configuration
variable "virtual_hubs" {
  description = "Configuration for Virtual WAN hubs"
  type = map(object({
    location                      = string
    environment                   = string  # prod, dev, etc.
    address_prefix                = string  # /23 or /24 recommended
    hub_type                      = optional(string, "secure")  # "secure" or "standard" 
    enable_expressroute_gateway   = optional(bool, true)
    expressroute_scale_units      = optional(number, 1)
    enable_vpn_gateway           = optional(bool, false)
    vpn_scale_units              = optional(number, 1)
    enable_firewall              = optional(bool, true)   # Set false for standard hubs
    firewall_sku                 = optional(string, "Standard")
    firewall_policy_id           = optional(string, null)
    firewall_public_ip_count     = optional(number, 1)
    enable_routing_intent        = optional(bool, true)   # Only for secure hubs
    routing_preference           = optional(string, "ASPath")  # ASPath recommended for optimal routing
  }))
  
  validation {
    condition = alltrue([
      for key, hub in var.virtual_hubs : can(cidrnetmask(hub.address_prefix))
    ])
    error_message = "All hub address prefixes must be valid CIDR blocks."
  }
  
  validation {
    condition = alltrue([
      for key, hub in var.virtual_hubs : 
      hub.hub_type == "secure" ? hub.enable_firewall == true : true
    ])
    error_message = "Secure hubs must have enable_firewall = true."
  }
  
  validation {
    condition = alltrue([
      for key, hub in var.virtual_hubs : 
      hub.hub_type == "standard" ? hub.enable_routing_intent == false : true
    ])
    error_message = "Standard hubs cannot have routing_intent enabled (no firewall)."
  }
}

# Firewall policies for different environments
variable "firewall_policies" {
  description = "Azure Firewall policies for different environments"
  type = map(object({
    location    = string
    sku         = optional(string, "Standard")
    dns_servers = optional(list(string), [])
  }))
  default = {}
}

# VNet connections to Virtual Hubs
variable "vnet_connections" {
  description = "Virtual Network connections to Virtual Hubs"
  type = map(object({
    hub_key                    = string
    vnet_id                   = string
    internet_security_enabled = optional(bool, true)
    associated_route_table_id = optional(string, null)
    propagated_route_tables = optional(list(object({
      labels          = optional(list(string), [])
      route_table_ids = optional(list(string), [])
    })), [])
    static_routes = optional(list(object({
      name                = string
      address_prefixes    = list(string)
      next_hop_ip_address = string
    })), [])
  }))
  default = {}
}

# Custom route tables for advanced routing
variable "custom_route_tables" {
  description = "Custom route tables for Virtual Hubs"
  type = map(object({
    hub_key = string
    labels  = optional(list(string), [])
    routes = optional(list(object({
      name              = string
      destinations_type = string
      destinations      = list(string)
      next_hop_type     = string
      next_hop          = string
    })), [])
  }))
  default = {}
}

# ExpressRoute configuration
variable "expressroute_circuits" {
  description = "ExpressRoute circuits to connect to Virtual Hubs"
  type = map(object({
    hub_key              = string
    circuit_id           = string
    authorization_key    = optional(string, null)
    enable_internet_security = optional(bool, false)
  }))
  default = {}
}

# VPN Site configuration for site-to-site VPN
variable "vpn_sites" {
  description = "VPN sites for site-to-site connectivity"
  type = map(object({
    hub_key           = string
    address_cidrs     = list(string)
    device_vendor     = optional(string, "Generic")
    device_model      = optional(string, "VPN")
    link_speed_in_mbps = optional(number, 50)
    links = list(object({
      name          = string
      fqdn_or_ip    = string
      bgp = optional(object({
        asn             = number
        bgp_peering_address = string
      }), null)
    }))
  }))
  default = {}
}

# Network Manager integration
variable "enable_network_manager_integration" {
  description = "Enable integration with Azure Virtual Network Manager"
  type        = bool
  default     = true
}

variable "network_manager_config" {
  description = "Configuration for Azure Virtual Network Manager integration"
  type = object({
    network_manager_id = optional(string, null)
    security_admin_configuration_id = optional(string, null)
    connectivity_topology = optional(string, "Mesh")
    global_mesh_enabled = optional(bool, true)
  })
  default = {}
}

# Test Infrastructure Provisioning (TiP) Configuration
variable "deploy_test_vms" {
  description = "Deploy test VMs for Virtual WAN connectivity testing (TiP - Test Infrastructure Provisioning)"
  type        = bool
  default     = false
}

# Intent Layer Configuration for AVNM Security Admin Rules
variable "intent_layer" {
  description = "Intent layer configuration for cloud-agnostic security policies"
  type = object({
    enabled                = optional(bool, true)
    deploy_azure_intent   = optional(bool, true)
    deploy_aws_intent     = optional(bool, false)
    
    security_rules = optional(map(object({
      name        = string
      description = string
      action      = string  # Allow, Deny
      priority    = number
      direction   = string  # Inbound, Outbound
      
      source = object({
        type   = string      # ServiceTag, IPPrefix, NetworkGroup, Any
        values = list(string)
      })
      
      destination = object({
        type   = string      # ServiceTag, IPPrefix, NetworkGroup, Any
        values = list(string)
      })
      
      protocol = string      # Any, Tcp, Udp, Icmp
      ports    = list(string)
      
      azure_mapping = optional(object({
        network_groups                    = optional(list(string), [])
        applies_to_vwan_hubs             = optional(bool, false)
        applies_to_test_infrastructure   = optional(bool, false)
        conditional_deployment           = optional(bool, false)
        bidirectional                    = optional(bool, false)
        applies_to_dmz_only             = optional(bool, false)
      }), {})
      
      aws_mapping = optional(object({
        target_ou_ids       = optional(list(string), [])
        apply_to_all_vpcs   = optional(bool, false)
        vpc_tags            = optional(map(list(string)), {})
        source_sg_tags      = optional(map(list(string)), {})
        destination_sg_tags = optional(map(list(string)), {})
      }), {})
    })), {})
    
    azure_network_groups = optional(map(object({
      name                   = string
      description            = string
      member_type            = string  # VirtualNetwork
      conditional_deployment = optional(bool, false)
      
      conditions = optional(list(object({
        field    = string
        operator = string  # Equals, In, Contains
        values   = list(string)
      })), [])
    })), {})
    
    aws_config = optional(object({
      firewall_manager_policy_name    = optional(string, "global-security-policy")
      target_organizational_units     = optional(list(string), [])
      security_group_tags            = optional(map(string), {})
    }), {})
  })
  default = {
    enabled             = true
    deploy_azure_intent = true
    deploy_aws_intent   = false
    security_rules      = {}
    azure_network_groups = {}
    aws_config = {}
  }
}
