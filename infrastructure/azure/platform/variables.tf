# General variables
variable "location" {
  description = "Specifies the main Azure region in the tenant."
  type        = string
  sensitive   = false
}

variable "suffix" {
  description = "Specifies the suffix for all Azure resources."
  type        = string
  sensitive   = false
  validation {
    condition     = length(var.suffix) >= 2 && length(var.suffix) <= 8
    error_message = "Please specify a suffix with more than two and less than 8 characters."
  }
  validation {
    condition     = length(regexall("[^[:alnum:]]", var.suffix)) <= 0
    error_message = "Please specify a suffix only containing alphanumeric characters."
  }
}

variable "owner" {
  description = "Specifies the owner of the Azure resources."
  type        = string
  sensitive   = false
  default     = ""
}

variable "hub_prefix" {
  description = "Specifies the prefix to be used when creating a hub virtual network."
  type        = string
  sensitive   = false
  default     = "hub-vnet"
  validation {
    condition     = length(var.hub_prefix) >= 2 && length(var.hub_prefix) <= 10
    error_message = "Please specify a hub prefix with more than two and less than 10 characters."
  }
}

variable "spoke_prefix" {
  description = "Specifies the prefix to be used for spoke virtual networks."
  type        = string
  sensitive   = false
  default     = "spoke-vnet"
  validation {
    condition     = length(var.spoke_prefix) >= 2 && length(var.spoke_prefix) <= 10
    error_message = "Please specify a spoke prefix with more than two and less than 10 characters."
  }
}

variable "environments" {
  description = "Specifies the network environments created within the environment."
  type        = list(string)
  sensitive   = false
  validation {
    condition     = length([for item in var.environments : true if length(regexall("[^[:lower:]]", item)) > 0]) <= 0
    error_message = "Please specify environment names only containing lowercase characters."
  }
}

variable "tags" {
  description = "Specifies the tags that you want to apply to all resources."
  type        = map(string)
  sensitive   = false
  default     = {}
  validation {
    condition     = length([for key, value in var.tags : true if length(regexall("[^[:lower:]]", key)) > 0 || length(regexall("[^[:lower:]]", value)) > 0]) <= 0
    error_message = "Please specify a lower case key and value for all tags."
  }
}

# Platform variables
variable "organization_name" {
  description = "Specifies the name of the organization."
  type        = string
  sensitive   = false
  validation {
    condition     = length(var.organization_name) >= 2
    error_message = "Please specify an organization name with more than two characters."
  }
}

# Virtual WAN Global Configuration
variable "enable_virtual_wan" {
  description = "Enable Azure Virtual WAN for global connectivity instead of traditional hub-spoke"
  type        = bool
  sensitive   = false
  default     = false
}

variable "virtual_wan_configuration" {
  description = "Configuration for Azure Virtual WAN"
  type = object({
    type                              = optional(string, "Standard") # Standard or Basic
    allow_branch_to_branch_traffic    = optional(bool, true)
    allow_vnet_to_vnet_traffic        = optional(bool, true)
    disable_vpn_encryption            = optional(bool, false)
    office365_local_breakout_category = optional(string, "OptimizeAndAllow")
  })
  sensitive = false
  default = {
    type                              = "Standard"
    allow_branch_to_branch_traffic    = true
    allow_vnet_to_vnet_traffic        = true
    disable_vpn_encryption            = false
    office365_local_breakout_category = "OptimizeAndAllow"
  }
}

# Secure Hub Deployment Control
variable "deploy_secure_hubs" {
  description = "Pipeline parameter to control whether Virtual WAN hubs are deployed with Azure Firewall (secure hubs) or as standard hubs"
  type        = bool
  sensitive   = false
  default     = true
  validation {
    condition     = var.deploy_secure_hubs != null
    error_message = "deploy_secure_hubs must be explicitly set to true or false."
  }
}

# Test Infrastructure Provisioning (TiP) Control
variable "deploy_tip_infrastructure" {
  description = "Pipeline parameter to enable Test Infrastructure Provisioning (TiP) - deploys test VMs for connectivity testing"
  type        = bool
  sensitive   = false
  default     = false
}

variable "global_platform_subscription_id" {
  description = "Specifies the subscription id for global network resources."
  type        = string
  sensitive   = false
  validation {
    condition     = length(regexall("^[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}$", var.global_platform_subscription_id)) == 1
    error_message = "Please specify a valid subscription id that follows the expected pattern."
  }
}

variable "enable_ddos_protection_plan" {
  description = "Specifies whether the ddos protection plan deployment should be enabled."
  type        = bool
  sensitive   = false
  nullable    = false
  default     = false
}

variable "enable_sentinel" {
  description = "Specifies whether sentinel should be enabled."
  type        = bool
  sensitive   = false
  nullable    = false
  default     = false
}

variable "enable_management_group_settings_update" {
  description = "Specifies whether the management group settings should be updated. This will force the playground management group to be the default management group for subscriptions and will enforce Entra ID permissions for management group creation."
  type        = bool
  sensitive   = false
  nullable    = false
  default     = false
}

variable "enable_cloud_security_benchmark_settings_update" {
  description = "Specifies whether the cloud security benchmark settings should be updated to be in line with the platform capabilities and requirements."
  type        = bool
  sensitive   = false
  nullable    = false
  default     = true
}

variable "allowed_resource_providers" {
  description = "Specifies the list of allowed resource providers."
  type        = list(string)
  sensitive   = false
}

variable "denied_resource_types" {
  description = "Specifies the list of denied resource types within the list of allowed resource providers."
  type        = list(string)
  sensitive   = false
}

variable "geo_region_mapping" {
  description = "Specifies the mapping of geos to Azure Regions."
  type = list(object({
    geo_name                     = string
    geo_platform_subscription_id = string
    geo_platform_location        = string
    regions = optional(list(object({
      azure_region_name = string
      environments = list(object({
        environment_name = string
        network = object({
          subscription_id                      = string
          dns_environment                      = string
          address_space_allocated              = list(string)
          address_space_network_hub            = string
          address_space_gateway_subnet         = string
          address_space_azfw_subnet            = string
          address_space_azfw_management_subnet = optional(string, "") # Management subnet for Basic SKU firewall
          address_space_dns_inbound_subnet     = string
          address_space_dns_outbound_subnet    = string
          ergw_sku                             = optional(string, "ErGw1AZ")
          azfw_sku                             = optional(string, "Basic") # Changed default from Standard to Basic for cost savings

          # Virtual WAN specific configuration
          enable_virtual_wan             = optional(bool, false)  # Enable Virtual WAN instead of traditional hub-spoke
          virtual_hub_address_space      = optional(string, null) # /23 recommended for Virtual WAN hubs
          enable_expressroute_gateway    = optional(bool, true)
          expressroute_scale_units       = optional(number, 1) # 1-10 for Virtual WAN
          enable_vpn_gateway             = optional(bool, false)
          vpn_scale_units                = optional(number, 1) # 1-20 for Virtual WAN
          enable_azure_firewall          = optional(bool, true)
          azure_firewall_sku             = optional(string, "Standard") # Standard, Premium, Basic
          azure_firewall_public_ip_count = optional(number, 1)
          enable_routing_intent          = optional(bool, true)       # Enable secure hub functionality
          hub_routing_preference         = optional(string, "ASPath") # ASPath or VpnGateway
        })
      }))
    })), [])
  }))
  sensitive = false

  # Name validations
  validation {
    condition     = length([for item in var.geo_region_mapping[*].geo_name : true if length(item) < 2 || length(item) > 8]) <= 0
    error_message = "Please use geo names with more than two and less than 8 characters."
  }
  # validation {
  #   condition = length([for item in flatten(flatten(var.geo_region_mapping[*].regions[*].environments[*].environment_name)): true if !contains(var.environments, item)]) <= 0
  #   error_message = "Please only use environment names included in the environments list parameter."
  # }

  # Location validations
  # validation {
  #   condition = length([for item in var.geo_region_mapping: true if !contains(var.geo_region_mapping[index(var.geo_region_mapping, item)].regions[*].azure_region_name, item.geo_platform_location)]) <= 0
  #   error_message = "Please use a geo region that is also listed in the respective geo region list."
  # }

  # Environment validations
  # validation {
  #   condition     = length([for item in flatten(flatten(var.geo_region_mapping[*].regions[*].environments[*].network.dns_environment)) : true if !contains(var.environments, item)]) <= 0
  #   error_message = "Please provide valid DNS environment mapping. The environment name must exist within the list specified under the 'environments' list."
  # }

  # Subscription validations
  validation {
    condition     = length([for item in var.geo_region_mapping[*].geo_platform_subscription_id : true if length(regexall("^[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}$", item)) <= 0]) <= 0
    error_message = "Please provide valid subscription IDs for the geo platform subscription IDs."
  }
  validation {
    condition     = length([for item in flatten(flatten(var.geo_region_mapping[*].regions[*].environments[*].network.subscription_id)) : true if length(regexall("^[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}$", item)) <= 0]) <= 0
    error_message = "Please provide valid subscription IDs for the network subscription IDs."
  }

  # Network CIDR validations
  validation {
    condition     = length([for item in flatten(flatten(var.geo_region_mapping[*].regions[*].environments[*].network.address_space_network_hub)) : true if !can(cidrnetmask(item))]) <= 0
    error_message = "Please provide valid network hub address space in CIDR notation (e.g. 10.0.0.0/20)."
  }
  validation {
    condition     = length([for item in flatten(flatten(var.geo_region_mapping[*].regions[*].environments[*].network.address_space_gateway_subnet)) : true if !can(cidrnetmask(item))]) <= 0
    error_message = "Please provide valid gateway subnet address space in CIDR notation (e.g. 10.0.0.0/24)."
  }
  validation {
    condition     = length([for item in flatten(flatten(var.geo_region_mapping[*].regions[*].environments[*].network.address_space_azfw_subnet)) : true if !can(cidrnetmask(item))]) <= 0
    error_message = "Please provide valid azure firewall subnet address space in CIDR notation (e.g. 10.0.0.0/24)."
  }
  validation {
    condition     = length([for item in flatten(flatten(var.geo_region_mapping[*].regions[*].environments[*].network.address_space_dns_inbound_subnet)) : true if !can(cidrnetmask(item))]) <= 0
    error_message = "Please provide valid DNS inbound subnet address space in CIDR notation (e.g. 10.0.0.0/24)."
  }
  validation {
    condition     = length([for item in flatten(flatten(var.geo_region_mapping[*].regions[*].environments[*].network.address_space_dns_outbound_subnet)) : true if !can(cidrnetmask(item))]) <= 0
    error_message = "Please provide valid DNS outbound subnet address space in CIDR notation (e.g. 10.0.0.0/24)."
  }

  # Network SKU validations
  validation {
    condition     = length([for item in flatten(flatten(var.geo_region_mapping[*].regions[*].environments[*].network.ergw_sku)) : true if !contains(["Basic", "Standard", "HighPerformance", "UltraPerformance", "ErGw1AZ", "ErGw2AZ", "ErGw3AZ"], item)]) <= 0
    error_message = "Please use an allowed value for the express route gateway sku: \"Basic\", \"Standard\", \"HighPerformance\", \"UltraPerformance\", \"ErGw1AZ\", \"ErGw2AZ\" or \"ErGw3AZ\"."
  }
  validation {
    condition     = length([for item in flatten(flatten(var.geo_region_mapping[*].regions[*].environments[*].network.azfw_sku)) : true if !contains(["Basic", "Standard", "Premium"], item)]) <= 0
    error_message = "Please use an allowed value for the firewall sku: \"Basic\", \"Standard\", \"Premium\"."
  }
}

# Additional variables from tfvars
variable "management_group_name" {
  description = "Specifies the name of the management group for landing zones."
  type        = string
  sensitive   = false
  default     = "landing-zones"
}

variable "admin_entra_id_group_object_id" {
  description = "Specifies the object ID of the admin Entra ID group."
  type        = string
  sensitive   = false
  default     = null
}

variable "reader_entra_id_group_object_id" {
  description = "Specifies the object ID of the reader Entra ID group."
  type        = string
  sensitive   = false
  default     = null
}

variable "ea_billing_details" {
  description = "Specifies the Enterprise Agreement billing details for subscription creation."
  type = object({
    billing_account_name    = optional(string, null)
    enrollment_account_name = optional(string, null)
  })
  sensitive = false
  default   = null
}

variable "mca_billing_details" {
  description = "Specifies the Microsoft Customer Agreement billing details for subscription creation."
  type = object({
    billing_account_name = optional(string, null)
    billing_profile_name = optional(string, null)
    invoice_section_name = optional(string, null)
  })
  sensitive = false
  default   = null
}

variable "vnet_spoke_details" {
  description = "Specifies the virtual network spoke configuration details."
  type = object({
    enabled          = bool
    name_prefix      = string
    address_prefixes = list(string)
    dns_servers      = list(string)
  })
  sensitive = false
  default = {
    enabled          = false
    name_prefix      = "spoke-vnet"
    address_prefixes = []
    dns_servers      = []
  }
}

# ================================================================
# INTENT LAYER - CLOUD-AGNOSTIC SECURITY POLICY VARIABLES
# ================================================================

# Pipeline override variables for intent layer deployment
variable "intent_layer_deploy_azure_intent" {
  description = "Pipeline parameter to enable/disable Azure intent layer deployment"
  type        = bool
  default     = false
  sensitive   = false
}

variable "intent_layer_deploy_aws_intent" {
  description = "Pipeline parameter to enable/disable AWS intent layer deployment"
  type        = bool
  default     = false
  sensitive   = false
}

# Pipeline override variable for test VM deployment
variable "deploy_test_vms" {
  description = "Pipeline parameter to enable/disable test VM deployment for Virtual WAN connectivity testing"
  type        = bool
  default     = false
  sensitive   = false
}

variable "intent_layer" {
  description = "Cloud-agnostic intent layer configuration for unified security policy management across Azure and AWS"
  type = object({
    # Global enablement
    enabled = optional(bool, false)

    # Cloud provider deployment flags (overridden by pipeline)
    deploy_azure_intent = optional(bool, true)
    deploy_aws_intent   = optional(bool, false)

    # Cloud-agnostic security rules
    security_rules = optional(map(object({
      name        = string
      description = string
      action      = string # "Allow" or "Deny"
      priority    = number
      direction   = string # "Inbound" or "Outbound"
      protocol    = string # "Tcp", "Udp", "Any", etc.
      ports       = list(string)

      source = object({
        type   = string # "ServiceTag", "IPPrefix", "Any", "NetworkGroup"
        values = list(string)
      })

      destination = object({
        type   = string # "ServiceTag", "IPPrefix", "Any", "NetworkGroup"
        values = list(string)
      })

      # Azure-specific mapping
      azure_mapping = optional(object({
        network_groups       = optional(list(string), [])
        applies_to_vwan_hubs = optional(bool, false)
        applies_to_dmz_only  = optional(bool, false)
        bidirectional        = optional(bool, false)
      }), {})

      # AWS-specific mapping
      aws_mapping = optional(object({
        target_ou_ids       = optional(list(string), [])
        vpc_tags            = optional(map(list(string)), {})
        source_sg_tags      = optional(map(list(string)), {})
        destination_sg_tags = optional(map(list(string)), {})
        apply_to_all_vpcs   = optional(bool, false)
      }), {})
    })), {})

    # Azure Network Manager network groups
    azure_network_groups = optional(map(object({
      name        = string
      description = string
      member_type = string # "VirtualNetwork", "Subnet"

      conditions = optional(list(object({
        field    = string # "tags.Environment", "name", "location"
        operator = string # "Equals", "In", "Contains", "NotEquals"
        values   = list(string)
      })), [])

      static_members = optional(list(string), [])
    })), {})

    # AWS configuration
    aws_config = optional(object({
      firewall_manager_policy_name = string
      target_organizational_units  = list(string)
      security_group_tags          = map(string)
      }), {
      firewall_manager_policy_name = "adia-intent-layer-policy"
      target_organizational_units  = []
      security_group_tags = {
        ManagedBy = "ADIA-Intent-Layer"
      }
    })
  })

  sensitive = false
  default = {
    enabled = false
  }

  validation {
    condition     = length(keys(try(var.intent_layer.security_rules, {}))) <= 1000
    error_message = "Maximum of 1000 security rules allowed in intent layer."
  }

  validation {
    condition = alltrue([
      for rule_name, rule in try(var.intent_layer.security_rules, {}) :
      contains(["Allow", "Deny"], rule.action)
    ])
    error_message = "Rule action must be either 'Allow' or 'Deny'."
  }

  validation {
    condition = alltrue([
      for rule_name, rule in try(var.intent_layer.security_rules, {}) :
      contains(["Inbound", "Outbound"], rule.direction)
    ])
    error_message = "Rule direction must be either 'Inbound' or 'Outbound'."
  }

  validation {
    condition = alltrue([
      for rule_name, rule in try(var.intent_layer.security_rules, {}) :
      rule.priority >= 100 && rule.priority <= 4096
    ])
    error_message = "Rule priority must be between 100 and 4096."
  }
}
