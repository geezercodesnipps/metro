# ================================================================
# INTENT LAYER VARIABLES
# ================================================================

variable "enable_azure_intent" {
  type        = bool
  default     = true
  description = "Enable Azure AVNM Security Admin Rules for intent layer"
}

variable "enable_aws_intent" {
  type        = bool
  default     = false
  description = "Enable AWS Security Groups + Firewall Manager for intent layer"
}

variable "suffix" {
  type        = string
  description = "Suffix for resource naming"
}

variable "azure_network_manager_id" {
  type        = string
  default     = ""
  description = "Azure Network Manager ID (required when enable_azure_intent = true)"
}

variable "azure_security_admin_configuration_id" {
  type        = string
  default     = ""
  description = "Azure Network Manager Security Admin Configuration ID to use (required when enable_azure_intent = true)"
}

variable "existing_network_group_ids" {
  type        = list(string)
  default     = []
  description = "Existing network group IDs to include in rule collections (e.g., spoke-vnets-network-group from file_new_tenant)"
}

variable "intent_rules" {
  type = map(object({
    name        = string
    description = string
    action      = string # "Allow" or "Deny"
    priority    = number
    direction   = string # "Inbound" or "Outbound"
    protocol    = string # "Tcp", "Udp", "Any", etc.
    ports       = list(string)
    
    source = object({
      type   = string       # "ServiceTag", "IPPrefix", "Any", "NetworkGroup"
      values = list(string)
    })
    
    destination = object({
      type   = string       # "ServiceTag", "IPPrefix", "Any", "NetworkGroup"  
      values = list(string)
    })
    
    # Azure-specific mapping
    azure_mapping = optional(object({
      network_groups         = optional(list(string), [])
      applies_to_vwan_hubs  = optional(bool, false)
      applies_to_dmz_only   = optional(bool, false)
      bidirectional         = optional(bool, false)
    }), {})
    
    # AWS-specific mapping
    aws_mapping = optional(object({
      target_ou_ids = optional(list(string), [])
      vpc_tags = optional(map(list(string)), {})
      source_sg_tags = optional(map(list(string)), {})
      destination_sg_tags = optional(map(list(string)), {})
      apply_to_all_vpcs = optional(bool, false)
    }), {})
  }))
  description = "Map of cloud-agnostic security intent rules"
  default     = {}
}

variable "azure_network_groups" {
  type = map(object({
    name        = string
    description = string
    member_type = string # "VirtualNetwork", "Subnet"
    
    conditions = optional(list(object({
      field    = string # "tags.Environment", "name", "location"
      operator = string # "Equals", "In", "Contains", "NotEquals"
      values   = list(string)
    })), [])
    
    # Static members (alternative to conditions)
    static_members = optional(list(string), [])
  }))
  description = "Azure Network Manager network groups definition for intent layer"
  default     = {}
}

variable "aws_config" {
  type = object({
    firewall_manager_policy_name = string
    target_organizational_units  = list(string)
    security_group_tags = map(string)
  })
  description = "AWS-specific configuration for intent layer"
  default = {
    firewall_manager_policy_name = "adia-intent-layer-policy"
    target_organizational_units  = []
    security_group_tags = {
      ManagedBy = "ADIA-Intent-Layer"
    }
  }
}

# Location and resource group for Azure resources
variable "location" {
  type        = string
  description = "Azure region for resource deployment"
  default     = "West Europe"
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name for Azure intent layer resources"
  default     = ""
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to all resources"
  default     = {}
}

# Pipeline control variables
variable "deploy_azure_intent" {
  type        = bool
  default     = true
  description = "Deploy Azure intent layer (overridden by pipeline parameter)"
}

variable "deploy_aws_intent" {
  type        = bool  
  default     = false
  description = "Deploy AWS intent layer (overridden by pipeline parameter)"
}

# AWS-specific configuration
variable "aws_vpc_id" {
  type        = string
  default     = ""
  description = "AWS VPC ID for security groups (required when enable_aws_intent = true)"
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region for resource deployment"
}
