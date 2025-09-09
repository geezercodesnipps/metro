# ================================================================
# ADIA METROPOLIS V2 - PLATFORM OUTPUTS
# ================================================================

# File New Tenant Outputs
output "network_manager_resource_id" {
  value       = module.file_new_tenant.network_manager_resource_id
  description = "Resource ID of the Azure Network Manager"
}

output "management_group_root_id" {
  value       = module.file_new_tenant.management_group_root_id
  description = "Root management group ID"
}

# File New Geo Outputs
output "geo_platform_configurations" {
  value = {
    for geo_name, geo_module in module.file_new_geo : geo_name => {
      management_group_prod_id     = geo_module.management_group_prod_id
      management_group_non_prod_id = geo_module.management_group_non_prod_id
      log_analytics_workspace_id   = geo_module.log_analytics_workspace_id
    }
  }
  description = "Geographic platform configurations"
}

# Virtual WAN Outputs (when enabled)
output "virtual_wan_configurations" {
  value = var.enable_virtual_wan ? {
    for geo_name, vwan_module in module.virtual_wan : geo_name => {
      virtual_wan_id      = vwan_module.virtual_wan_id
      virtual_hub_ids     = vwan_module.virtual_hub_ids
      firewall_ids        = vwan_module.firewall_ids
      firewall_policy_ids = vwan_module.firewall_policy_ids
    }
  } : {}
  description = "Virtual WAN configurations by geography"
}

# ================================================================
# INTENT LAYER OUTPUTS
# ================================================================

output "intent_layer_summary" {
  value = length(module.intent_layer) > 0 ? module.intent_layer[0].intent_layer_summary : {
    azure_enabled              = false
    aws_enabled                = false
    total_rules                = 0
    rules_processed            = 0
    rules_skipped_networkgroup = 0
    azure_resources            = null
    aws_resources              = null
    warnings                   = []
  }
  description = "Intent layer deployment summary"
}

output "intent_layer_azure_configuration" {
  value = length(module.intent_layer) > 0 && try(var.intent_layer.deploy_azure_intent, false) ? {
    security_admin_configuration_id = module.intent_layer[0].azure_security_admin_configuration_id
    network_group_ids               = module.intent_layer[0].azure_network_group_ids
    admin_rule_collection_id        = module.intent_layer[0].azure_admin_rule_collection_id
    rule_mappings                   = module.intent_layer[0].azure_rule_mappings
  } : null
  description = "Azure intent layer configuration details"
}

output "intent_layer_aws_configuration" {
  value = length(module.intent_layer) > 0 && try(var.intent_layer.deploy_aws_intent, false) ? {
    firewall_manager_config = module.intent_layer[0].aws_firewall_manager_config
    prepared_rules          = module.intent_layer[0].aws_prepared_rules
    validation_errors       = module.intent_layer[0].aws_validation_errors
    context                 = module.intent_layer[0].aws_context
    rule_mappings           = module.intent_layer[0].aws_rule_mappings
  } : null
  description = "AWS intent layer configuration details"
}

# Environment Outputs
output "environment_configurations" {
  value = {
    traditional_hub_spoke = {
      for env_key, env_module in module.file_new_environment : env_key => {
        virtual_network_hub_id     = env_module.virtual_network_hub_id
        firewall_id                = env_module.firewall_id
        log_analytics_workspace_id = env_module.log_analytics_workspace_id
      }
    }
  }
  description = "Environment configurations (traditional hub-spoke)"
}

# Regional Outputs
output "regional_configurations" {
  value = {
    for region_name, region_module in module.file_new_region : region_name => {
      storage_account_id = region_module.storage_account_id
    }
  }
  description = "Regional configurations"
}

# Network Manager Deployment Status
output "network_manager_deployments" {
  value = {
    connectivity_deployed   = length(azurerm_network_manager_deployment.network_manager_mesh_deployment_connectivity) > 0
    security_admin_deployed = length(azurerm_network_manager_deployment.network_manager_mesh_deployment_security_admin) > 0
    intent_layer_enabled    = try(var.intent_layer.enabled, false) && try(var.intent_layer.deploy_azure_intent, false)
    has_tenant_security     = local.has_tenant_security_config
    has_vwan_security       = local.has_vwan_security_config
    has_intent_security     = local.has_intent_security_config
  }
  description = "Network Manager deployment status"
}

# Deployment Summary
output "deployment_summary" {
  value = {
    tenant_name          = var.organization_name
    suffix               = var.suffix
    location             = var.location
    virtual_wan_enabled  = var.enable_virtual_wan
    intent_layer_enabled = try(var.intent_layer.enabled, false)

    geography_count   = length(module.file_new_geo)
    environment_count = length(module.file_new_environment)
    region_count      = length(module.file_new_region)

    deployment_timestamp = timestamp()
  }
  description = "Overall deployment summary"
}
