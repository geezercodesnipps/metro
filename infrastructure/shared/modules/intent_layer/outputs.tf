# ================================================================
# INTENT LAYER OUTPUTS
# ================================================================

output "intent_layer_summary" {
  value = {
    azure_enabled = var.enable_azure_intent
    aws_enabled   = var.enable_aws_intent
    total_rules   = length(var.intent_rules)
    
    # Count rules by type to show what was processed
    rules_processed = var.enable_azure_intent ? length({
      for k, v in var.intent_rules : k => v
      if v.source.type != "NetworkGroup" && v.destination.type != "NetworkGroup"
    }) : 0
    
    rules_skipped_networkgroup = var.enable_azure_intent ? length({
      for k, v in var.intent_rules : k => v
      if v.source.type == "NetworkGroup" || v.destination.type == "NetworkGroup"
    }) : 0
    
    azure_resources = var.enable_azure_intent ? {
      security_admin_config_id = var.azure_security_admin_configuration_id  # Use the tenant's security admin configuration ID
      network_groups_count     = length(azurerm_network_manager_network_group.intent_network_groups)
      admin_rules_count        = length(azurerm_network_manager_admin_rule.intent_based_rules)
    } : null
    
    aws_resources = var.enable_aws_intent ? {
      applicable_rules_count      = length(local.aws_applicable_rules)
      security_group_rules_count  = length(local.aws_security_group_rules)
      validation_errors_count     = length(local.aws_validation_errors)
      firewall_manager_config     = local.aws_firewall_manager_config
      account_id                  = try(data.aws_caller_identity.current[0].account_id, null)
      region                      = try(data.aws_region.current[0].name, null)
    } : null
    
    # Warning about NetworkGroup rules
    warnings = var.enable_azure_intent && length({
      for k, v in var.intent_rules : k => v
      if v.source.type == "NetworkGroup" || v.destination.type == "NetworkGroup"
    }) > 0 ? [
      "NetworkGroup-based intent rules are currently skipped in Azure AVNM implementation. Convert to IP-based rules or use connectivity configurations."
    ] : []
  }
  description = "Summary of intent layer deployment"
}

# Azure-specific outputs
output "azure_security_admin_configuration_id" {
  value       = var.enable_azure_intent ? var.azure_security_admin_configuration_id : null
  description = "Azure Network Manager Security Admin Configuration ID - Intent Layer uses tenant's security admin config"
}

output "azure_network_group_ids" {
  value = var.enable_azure_intent ? {
    for k, v in azurerm_network_manager_network_group.intent_network_groups : k => v.id
  } : {}
  description = "Map of Azure Network Manager Network Group IDs"
}

output "azure_admin_rule_collection_id" {
  value       = var.enable_azure_intent ? try(azurerm_network_manager_admin_rule_collection.intent_rule_collection[0].id, null) : null
  description = "Azure Network Manager Admin Rule Collection ID"
}

# AWS-specific outputs (Firewall Manager preparation)
output "aws_firewall_manager_config" {
  value       = var.enable_aws_intent ? local.aws_firewall_manager_config : null
  description = "AWS Firewall Manager configuration prepared by intent layer"
}

output "aws_prepared_rules" {
  value       = var.enable_aws_intent ? local.aws_security_group_rules : {}
  description = "AWS security group rules prepared for Firewall Manager"
}

output "aws_validation_errors" {
  value       = var.enable_aws_intent ? local.aws_validation_errors : []
  description = "AWS rule validation errors that need to be addressed"
}

output "aws_context" {
  value = var.enable_aws_intent ? {
    account_id = try(data.aws_caller_identity.current[0].account_id, null)
    region     = try(data.aws_region.current[0].name, null)
  } : null
  description = "AWS context information"
}

# Rule mappings for other modules
output "azure_rule_mappings" {
  value = var.enable_azure_intent ? {
    for k, v in azurerm_network_manager_admin_rule.intent_based_rules : k => {
      rule_id     = v.id
      priority    = v.priority
      action      = v.action
      direction   = v.direction
    }
  } : {}
  description = "Azure AVNM rule mappings for integration with other modules"
}

output "aws_rule_mappings" {
  value = var.enable_aws_intent ? {
    for k, v in local.aws_security_group_rules : k => {
      rule_name     = v.name
      direction     = v.direction
      action        = v.action
      protocol      = v.protocol
      ports         = v.ports
      priority      = v.priority
      aws_mapping   = v.aws_mapping
    }
  } : {}
  description = "AWS rule mappings prepared for Firewall Manager integration"
}
