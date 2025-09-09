# Validation checks for geo region mapping against environments
check "geo_region_mapping_validation" {
  assert {
    condition     = length(local.invalid_dns_environments) == 0
    error_message = "Invalid DNS environment mapping found. The following DNS environments are not in the environments list: ${join(", ", local.invalid_dns_environments)}. Please provide valid DNS environment mapping."
  }
}

# Validation checks for denied resource types against allowed resource providers
check "denied_resource_types_validation" {
  assert {
    condition     = length(local.invalid_denied_resource_types) == 0
    error_message = "The following denied resource types are not in the list of allowed resource providers: ${join(", ", local.invalid_denied_resource_types)}. Please specify resources included in the list of allowed resource providers."
  }
}

module "file_new_tenant" {
  source = "./modules/file_new_tenant"

  providers = {
    azurerm         = azurerm
    azurerm.network = azurerm.global_network
    time            = time
    null            = null
  }

  # General variables
  location = var.location
  suffix   = var.suffix
  tags     = var.tags

  # File New Tenant variables
  organization_name                               = var.organization_name
  locations_supported                             = local.locations_list
  environments                                    = var.environments
  hub_prefix                                      = var.hub_prefix
  spoke_prefix                                    = var.spoke_prefix
  subscription_ids_connectivity                   = local.subscription_ids_network
  subscription_ids_management                     = local.subscription_ids_management
  global_platform_subscription_id                 = var.global_platform_subscription_id
  enable_ddos_protection_plan                     = var.enable_ddos_protection_plan
  enable_management_group_settings_update         = var.enable_management_group_settings_update
  enable_cloud_security_benchmark_settings_update = var.enable_cloud_security_benchmark_settings_update
  deploy_test_vms                                 = var.deploy_test_vms
}

# Azure Virtual WAN Resource Groups
resource "azurerm_resource_group" "virtual_wan_rgs" {
  for_each = local.virtual_wan_resource_groups

  name     = each.value.name
  location = each.value.location
  tags     = each.value.tags

  provider = azurerm.global_network
}

# Azure Virtual WAN Module (alternative to traditional hub-spoke)
module "virtual_wan" {
  count  = var.enable_virtual_wan ? 1 : 0
  source = "./modules/azure_virtual_wan"

  providers = {
    azurerm = azurerm.global_network
    azapi   = azapi
  }

  # General variables
  location            = var.location
  suffix              = var.suffix
  resource_group_name = azurerm_resource_group.virtual_wan_rgs["vwan"].name
  tags                = var.tags

  # Virtual WAN configuration
  virtual_hubs = local.virtual_wan_hubs

  # Firewall policies
  firewall_policies = local.virtual_wan_firewall_policies

  # VNet connections (populated after spoke VNets are created)
  vnet_connections = {}

  # Network Manager configuration
  enable_network_manager_integration = true
  network_manager_config = {
    network_manager_id              = module.file_new_tenant.network_manager_resource_id
    security_admin_configuration_id = length(module.file_new_tenant.network_manager_security_admin_configuration_ids) > 0 ? module.file_new_tenant.network_manager_security_admin_configuration_ids[0] : null
    connectivity_topology           = "Mesh"
    global_mesh_enabled             = true
  }

  # Intent Layer Configuration - Cloud-agnostic security policies
  intent_layer = var.intent_layer

  depends_on = [
    module.file_new_tenant,
    azurerm_resource_group.virtual_wan_rgs
  ]
}

module "file_new_geo" {
  source = "./modules/file_new_geo"

  providers = {
    azurerm = azurerm
    azapi   = azapi
    random  = random
    time    = time
  }

  for_each = local.geos_details

  # General variables
  location                 = each.value.geo_platform_location
  suffix                   = var.suffix
  tags                     = var.tags
  diagnostics_setting_name = local.diagnostics_setting_name

  # File New Geo variables
  geo_name                     = each.key
  geo_platform_subscription_id = each.value.geo_platform_subscription_id
  geo_region_names             = each.value.geo_region_names
  enable_sentinel              = var.enable_sentinel
  allowed_resource_providers   = var.allowed_resource_providers
  denied_resource_types        = var.denied_resource_types
  spoke_prefix                 = var.spoke_prefix

  # File New Tenant variables
  artifacts_management_group_root_setup_completed = module.file_new_tenant.artifacts_management_group_root_setup_completed
  management_group_root_id                        = module.file_new_tenant.management_group_root_id
  management_group_landing_zones_id               = module.file_new_tenant.management_group_landing_zones_id
  management_group_platform_id                    = module.file_new_tenant.management_group_platform_id
  network_manager_resource_id                     = module.file_new_tenant.network_manager_resource_id
  network_ddos_protection_plan_id                 = module.file_new_tenant.network_ddos_protection_plan_id
}

module "file_new_region" {
  source = "./modules/file_new_region"

  providers = {
    azurerm = azurerm
    azapi   = azapi
  }

  for_each = local.locations_details

  # General variables
  location                 = each.key
  suffix                   = var.suffix
  tags                     = var.tags
  diagnostics_setting_name = local.diagnostics_setting_name

  # File New Region variables
  region_platform_subscription_id = each.value.geo_platform_subscription_id

  # File New Geo variables
  log_analytics_workspace_id = module.file_new_geo[each.value.geo_name].log_analytics_workspace_id

  # File New Tenant variables
  artifacts_management_group_root_setup_completed = module.file_new_tenant.artifacts_management_group_root_setup_completed
}

module "file_new_environment" {
  source = "./modules/file_new_environment"

  # Only deploy traditional hub-spoke for environments NOT using Virtual WAN
  for_each = {
    for key, value in local.environments_details : key => value
    if !try(value.network.enable_virtual_wan, false)
  }

  providers = {
    azurerm                = azurerm
    azurerm.global_network = azurerm.global_network
    azapi                  = azapi
  }

  # General variables
  location                 = each.value.azure_region_name
  suffix                   = var.suffix
  environment              = each.value.environment_name
  tags                     = var.tags
  diagnostics_setting_name = local.diagnostics_setting_name

  # File New Environment variables
  hub_prefix                           = var.hub_prefix
  spoke_prefix                         = var.spoke_prefix
  environment_network_subscription_id  = each.value.network.subscription_id
  address_space_network_hub            = each.value.network.address_space_network_hub
  address_space_gateway_subnet         = each.value.network.address_space_gateway_subnet
  address_space_azfw_subnet            = each.value.network.address_space_azfw_subnet
  address_space_azfw_management_subnet = try(each.value.network.address_space_azfw_management_subnet, "")
  address_space_dns_inbound_subnet     = each.value.network.address_space_dns_inbound_subnet
  address_space_dns_outbound_subnet    = each.value.network.address_space_dns_outbound_subnet
  ergw_sku                             = each.value.network.ergw_sku
  azfw_sku                             = each.value.network.azfw_sku
  # File New Region variables
  storage_account_id = module.file_new_region[each.value.azure_region_name].storage_account_id

  # File New Geo variables
  management_group_id        = contains(["prod", "production"], lower(each.value.environment_name)) ? module.file_new_geo[each.value.geo_name].management_group_prod_id : module.file_new_geo[each.value.geo_name].management_group_non_prod_id
  log_analytics_workspace_id = module.file_new_geo[each.value.geo_name].log_analytics_workspace_id

  # File New Tenant variables
  private_dns_zone_ids        = module.file_new_tenant.private_dns_zone_ids[each.value.network.dns_environment]
  network_manager_resource_id = module.file_new_tenant.network_manager_resource_id
}

# ================================================================
# INTENT LAYER - CLOUD-AGNOSTIC SECURITY POLICY (SHARED MODULE)
# ================================================================
# Deploy intent layer when enabled and intent rules are defined
module "intent_layer" {
  source = "../../shared/modules/intent_layer"

  # Only deploy if intent layer is enabled and rules are defined
  # Additionally, require that at least one cloud provider intent is actually enabled
  # CRITICAL: Use pipeline variables directly to prevent module creation when AWS intent is disabled
  count = (
    try(var.intent_layer.enabled, false) && 
    length(try(var.intent_layer.security_rules, {})) > 0 &&
    (var.intent_layer_deploy_azure_intent || var.intent_layer_deploy_aws_intent)
  ) ? 1 : 0

  providers = {
    azurerm          = azurerm
    aws.intent_layer = aws.intent_layer
  }

  # Cloud provider enablement (pipeline variables override tfvars)
  # CRITICAL: Pipeline variables take precedence to prevent AWS credential errors when AWS intent is disabled
  # When pipeline explicitly sets these variables, they override tfvars values
  enable_azure_intent = var.intent_layer_deploy_azure_intent
  enable_aws_intent   = var.intent_layer_deploy_aws_intent
  
  # Pipeline deployment control variables (use pipeline values directly)
  deploy_azure_intent = var.intent_layer_deploy_azure_intent
  deploy_aws_intent   = var.intent_layer_deploy_aws_intent

  # Azure configuration
  azure_network_manager_id              = module.file_new_tenant.network_manager_resource_id
  azure_security_admin_configuration_id = length(module.file_new_tenant.network_manager_security_admin_configuration_ids) > 0 ? module.file_new_tenant.network_manager_security_admin_configuration_ids[0] : null

  # Intent configuration from tfvars
  intent_rules         = try(var.intent_layer.security_rules, {})
  azure_network_groups = try(var.intent_layer.azure_network_groups, {})
  aws_config = try(var.intent_layer.aws_config, {
    firewall_manager_policy_name = "adia-intent-layer-policy"
    target_organizational_units  = []
    security_group_tags = {
      ManagedBy = "ADIA-Intent-Layer"
    }
  })

  # Existing network groups from other modules
  existing_network_group_ids = [module.file_new_tenant.network_manager_spoke_group_id]

  # General configuration
  suffix              = var.suffix
  location            = var.location
  resource_group_name = "rg-intent-layer-${var.suffix}-${var.location}"
  tags = merge(var.tags, {
    Component = "Intent-Layer"
    Purpose   = "Cloud-Agnostic-Security"
  })

  depends_on = [
    module.file_new_tenant
  ]
}

# ================================================================
# TEST INFRASTRUCTURE - TiP (Test Infrastructure Provisioning)
# ================================================================
# TiP - TEST INFRASTRUCTURE PROVISIONING MODULE
# Deploy test VMs for Virtual WAN connectivity testing when enabled
# ================================================================
module "test_vms" {
  count  = var.deploy_tip_infrastructure && var.enable_virtual_wan ? 1 : 0
  source = "./modules/test_vm"

  providers = {
    azurerm = azurerm.global_network
  }

  # General variables
  suffix              = var.suffix
  resource_group_name = azurerm_resource_group.virtual_wan_rgs["vwan"].name
  tags = merge(var.tags, {
    Component = "Test-Infrastructure-Provisioning"
    Purpose   = "Virtual-WAN-Connectivity-Testing"
    TiP       = "Enabled"
  })

  # Virtual WAN hub IDs from the virtual_wan module
  virtual_hub_ids = var.enable_virtual_wan ? {
    for hub_key, hub_config in local.virtual_wan_hubs :
    hub_key => module.virtual_wan[0].virtual_hub_ids[hub_key]
  } : {}

  # Network Manager spoke group ID for adding VNets to the group
  network_manager_spoke_group_id = module.file_new_tenant.network_manager_spoke_group_id

  # Test VM configuration for each region
  test_vms = var.enable_virtual_wan ? {
    for hub_key, hub_config in local.virtual_wan_hubs :
    "${hub_config.location}-test-vm" => {
      location                 = hub_config.location
      environment              = split("-", hub_key)[1] # Extract environment from hub key like "westeurope-dev"
      hub_key                  = hub_key
      vnet_address_space       = "10.${100 + index(keys(local.virtual_wan_hubs), hub_key)}.0.0/24" # 10.100.0.0/24, 10.101.0.0/24, etc.
      vm_subnet_address_prefix = "10.${100 + index(keys(local.virtual_wan_hubs), hub_key)}.0.0/26" # First /26 of each VNet
    }
  } : {}

  # VM configuration
  vm_size           = "Standard_B1s" # Small and cost-effective for testing
  enable_public_ips = false          # Use private connectivity via Virtual WAN
  admin_username    = "testuser"

  depends_on = [
    module.virtual_wan,
    module.file_new_geo,
    azurerm_resource_group.virtual_wan_rgs
  ]
}
