# ================================================================
# INTENT LAYER - CLOUD-AGNOSTIC SECURITY POLICY ABSTRACTION
# ================================================================
# This module translates cloud-agnostic security intent into 
# provider-specific implementations:
# - Azure: Azure Virtual Network Manager (AVNM) Security Admin Rules
# - AWS: AWS Security Groups via AWS Firewall Manager
# ================================================================

locals {
  # Filter rules by direction
  inbound_rules = {
    for name, rule in var.intent_rules : name => rule
    if rule.direction == "Inbound"
  }
  
  outbound_rules = {
    for name, rule in var.intent_rules : name => rule
    if rule.direction == "Outbound"
  }
  
  # Filter rules by action
  deny_rules = {
    for name, rule in var.intent_rules : name => rule
    if rule.action == "Deny"
  }
  
  allow_rules = {
    for name, rule in var.intent_rules : name => rule
    if rule.action == "Allow"
  }
}

# ================================================================
# AZURE IMPLEMENTATION - AVNM Security Admin Rules
# ================================================================

# Create network groups based on intent definitions
resource "azurerm_network_manager_network_group" "intent_network_groups" {
  for_each = var.enable_azure_intent ? var.azure_network_groups : {}
  
  name               = each.value.name
  network_manager_id = var.azure_network_manager_id
  description        = each.value.description
}

# Dynamic membership for network groups
resource "azurerm_network_manager_network_group" "intent_network_groups_dynamic" {
  for_each = var.enable_azure_intent ? {
    for k, v in var.azure_network_groups : k => v 
    if length(v.conditions) > 0
  } : {}
  
  name               = "${each.value.name}-dynamic"
  network_manager_id = var.azure_network_manager_id
  description        = "${each.value.description} (Dynamic membership)"
}

# Use the tenant's security admin configuration instead of creating our own
# This avoids the "shouldn't contain more than 1 security Configuration" error

# Create rule collection for intent-based rules (non-NetworkGroup rules)
resource "azurerm_network_manager_admin_rule_collection" "intent_rule_collection" {
  count = var.enable_azure_intent ? 1 : 0
  
  name                            = "intent-layer-rules-${var.suffix}"
  security_admin_configuration_id = var.azure_security_admin_configuration_id
  description                     = "Intent-based security rules collection"
  
  network_group_ids = concat(
    values(azurerm_network_manager_network_group.intent_network_groups)[*].id,
    var.existing_network_group_ids
  )
}

# Create separate rule collections for NetworkGroup-based rules - DISABLED FOR NOW
# resource "azurerm_network_manager_admin_rule_collection" "network_group_rule_collections" {
#   for_each = var.enable_azure_intent ? {
#     for rule_name, rule in var.intent_rules : rule_name => rule
#     if rule.source.type == "NetworkGroup" || rule.destination.type == "NetworkGroup"
#   } : {}
#   
#   name                            = "intent-${each.key}-${var.suffix}"
#   security_admin_configuration_id = azurerm_network_manager_security_admin_configuration.intent_security_config[0].id
#   description                     = "NetworkGroup-based rule: ${each.value.description}"
#   
#   # For NetworkGroup rules, apply to specific network groups based on the rule mapping
#   network_group_ids = [
#     for ng_name in try(each.value.azure_mapping.network_groups, []) :
#     azurerm_network_manager_network_group.intent_network_groups[ng_name].id
#     if can(azurerm_network_manager_network_group.intent_network_groups[ng_name])
#   ]
# }

# Regular intent rules (non-NetworkGroup rules)
resource "azurerm_network_manager_admin_rule" "intent_based_rules" {
  for_each = var.enable_azure_intent ? {
    for k, v in var.intent_rules : k => v
    if (try(v.source.type, "") != "NetworkGroup" && try(v.destination.type, "") != "NetworkGroup")
  } : {}
  
  name                     = each.value.name
  admin_rule_collection_id = azurerm_network_manager_admin_rule_collection.intent_rule_collection[0].id
  
  description = each.value.description
  action      = each.value.action
  direction   = each.value.direction
  priority    = each.value.priority
  protocol    = each.value.protocol
  
  # Source configuration
  source {
    address_prefix_type = (
      each.value.source.type == "ServiceTag" ? "ServiceTag" : 
      each.value.source.type == "IPPrefix" ? "IPPrefix" : "IPPrefix"
    )
    address_prefix = (
      each.value.source.type == "Any" ? "*" : 
      each.value.source.values[0]  # Use first CIDR block only - Azure AVNM doesn't support comma-separated
    )
  }
  
  # Destination configuration
  destination {
    address_prefix_type = (
      each.value.destination.type == "ServiceTag" ? "ServiceTag" : 
      each.value.destination.type == "IPPrefix" ? "IPPrefix" : "IPPrefix"
    )
    address_prefix = (
      each.value.destination.type == "Any" ? "*" : 
      each.value.destination.values[0]  # Use first CIDR block only - Azure AVNM doesn't support comma-separated
    )
  }
  
  # Port configuration
  destination_port_ranges = each.value.ports[0] == "*" ? ["0-65535"] : each.value.ports
  source_port_ranges      = ["0-65535"]
  
  timeouts {
    delete = "60m"
  }
}

# NetworkGroup-based rules (require special handling) - DISABLED FOR NOW
# resource "azurerm_network_manager_admin_rule" "network_group_based_rules" {
#   for_each = var.enable_azure_intent ? {
#     for k, v in var.intent_rules : k => v
#     if v.source.type == "NetworkGroup" || v.destination.type == "NetworkGroup"
#   } : {}
#   
#   name                     = each.value.name
#   admin_rule_collection_id = azurerm_network_manager_admin_rule_collection.network_group_rule_collections[each.key].id
#   
#   description = each.value.description
#   action      = each.value.action
#   direction   = each.value.direction
#   priority    = each.value.priority
#   protocol    = each.value.protocol
#   
#   # For NetworkGroup rules, we need to translate to broader IP ranges or use wildcards
#   # This is a simplified approach - in production, you'd want more specific CIDR blocks
#   source {
#     address_prefix_type = "IPPrefix"
#     address_prefix = (
#       each.value.source.type == "NetworkGroup" ? "10.0.0.0/8" :  # Use broad range for source network groups
#       each.value.source.type == "Any" ? "*" : 
#       join(",", each.value.source.values)
#     )
#   }
#   
#   destination {
#     address_prefix_type = "IPPrefix"
#     address_prefix = (
#       each.value.destination.type == "NetworkGroup" ? "10.0.0.0/8" :  # Use broad range for destination network groups
#       each.value.destination.type == "Any" ? "*" : 
#       join(",", each.value.destination.values)
#     )
#   }
#   
#   # Port configuration
#   destination_port_ranges = each.value.ports[0] == "*" ? ["0-65535"] : each.value.ports
#   source_port_ranges      = ["0-65535"]
#   
#   timeouts {
#     delete = "60m"
#   }
# }

# ================================================================
# AWS IMPLEMENTATION - Intent Layer Data Preparation for Firewall Manager
# ================================================================

# The AWS implementation focuses on data preparation and validation
# rather than direct resource creation. The actual policy creation
# is handled by the aws_firewall_manager module in the platform layer.

# Validate AWS intent rules and prepare data for Firewall Manager
locals {
  # Filter AWS-applicable rules - only when AWS intent is enabled AND deployment is requested
  aws_applicable_rules = var.enable_aws_intent && var.deploy_aws_intent ? {
    for name, rule in var.intent_rules : name => rule
    if can(rule.aws_mapping) || var.aws_config.target_organizational_units != []
  } : {}
  
  # Prepare security group rule data for Firewall Manager policies
  aws_security_group_rules = {
    for name, rule in local.aws_applicable_rules : name => {
      name        = rule.name
      description = rule.description
      direction   = rule.direction
      action      = rule.action
      protocol    = rule.protocol
      ports       = rule.ports
      priority    = rule.priority
      source      = rule.source
      destination = rule.destination
      
      # Enhanced AWS mapping with Firewall Manager specifics
      aws_mapping = merge(
        try(rule.aws_mapping, {}),
        {
          policy_type = "SecurityGroup"
          organizational_units = try(rule.aws_mapping.target_ou_ids, var.aws_config.target_organizational_units)
          resource_types = ["AWS::EC2::SecurityGroup"]
        }
      )
    }
  }
  
  # Validate rules for AWS compatibility
  aws_validation_errors = [
    for name, rule in local.aws_applicable_rules : {
      rule_name = name
      errors = compact([
        # Check if ports are valid for AWS
        length([for port in rule.ports : port if !can(regex("^[0-9]+$|^\\*$", port))]) > 0 ? "Invalid port format for AWS" : "",
        
        # Check if protocol is supported
        !contains(["Tcp", "Udp", "Any"], rule.protocol) ? "Protocol must be Tcp, Udp, or Any for AWS" : "",
        
        # Check if action is supported
        !contains(["Allow", "Deny"], rule.action) ? "Action must be Allow or Deny for AWS" : "",
        
        # Check if direction is supported
        !contains(["Inbound", "Outbound"], rule.direction) ? "Direction must be Inbound or Outbound for AWS" : "",
        
        # Check source/destination types
        !contains(["IPPrefix", "ServiceTag", "Any", "NetworkGroup"], rule.source.type) ? "Invalid source type for AWS" : "",
        !contains(["IPPrefix", "ServiceTag", "Any", "NetworkGroup"], rule.destination.type) ? "Invalid destination type for AWS" : ""
      ])
    }
    if length(compact([
      length([for port in rule.ports : port if !can(regex("^[0-9]+$|^\\*$", port))]) > 0 ? "port" : "",
      !contains(["Tcp", "Udp", "Any"], rule.protocol) ? "protocol" : "",
      !contains(["Allow", "Deny"], rule.action) ? "action" : "",
      !contains(["Inbound", "Outbound"], rule.direction) ? "direction" : "",
      !contains(["IPPrefix", "ServiceTag", "Any", "NetworkGroup"], rule.source.type) ? "source" : "",
      !contains(["IPPrefix", "ServiceTag", "Any", "NetworkGroup"], rule.destination.type) ? "destination" : ""
    ])) > 0
  ]
}

# Create local file output for debugging AWS rule preparation (optional)
resource "local_file" "aws_intent_rules_debug" {
  count = length(local.aws_applicable_rules) > 0 ? 1 : 0
  
  content = jsonencode({
    aws_applicable_rules    = local.aws_applicable_rules
    aws_security_group_rules = local.aws_security_group_rules
    aws_validation_errors   = local.aws_validation_errors
    aws_config             = var.aws_config
  })
  
  filename = "${path.module}/aws-intent-rules-debug.json"
}

# Data source to check if AWS Firewall Manager is available in the region  
# Only evaluate when AWS intent is enabled AND deployment is requested AND there are applicable rules
# This triple-check ensures AWS resources are never evaluated when AWS intent is disabled
data "aws_caller_identity" "current" {
  count = var.enable_aws_intent && var.deploy_aws_intent && length(local.aws_applicable_rules) > 0 ? 1 : 0
  provider = aws.intent_layer
}

data "aws_region" "current" {
  count = var.enable_aws_intent && var.deploy_aws_intent && length(local.aws_applicable_rules) > 0 ? 1 : 0
  provider = aws.intent_layer
}

# Create a summary output for the Firewall Manager module to consume
locals {
  aws_firewall_manager_config = length(local.aws_applicable_rules) > 0 ? {
    rules_summary = {
      total_rules         = length(local.aws_applicable_rules)
      security_group_rules = length(local.aws_security_group_rules)
      validation_errors   = length(local.aws_validation_errors)
      has_errors         = length(local.aws_validation_errors) > 0
    }
    
    prepared_rules = local.aws_security_group_rules
    
    organizational_config = {
      target_organizational_units = var.aws_config.target_organizational_units
      policy_name                = var.aws_config.firewall_manager_policy_name
      security_group_tags        = var.aws_config.security_group_tags
    }
    
    aws_context = var.enable_aws_intent && var.deploy_aws_intent && length(local.aws_applicable_rules) > 0 && length(data.aws_caller_identity.current) > 0 ? {
      account_id = data.aws_caller_identity.current[0].account_id
      region     = data.aws_region.current[0].name
    } : null
  } : null
}

# ================================================================

