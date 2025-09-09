locals {
  # Resource providers to register
  resource_providers_to_register = [
    "Microsoft.Authorization",
    "microsoft.insights",
    "Microsoft.KeyVault",
    "Microsoft.ManagedIdentity",
    "Microsoft.Management",
    "Microsoft.Network",
    "Microsoft.OperationsManagement",
    "Microsoft.OperationalInsights",
    "Microsoft.Resources",
    "Microsoft.Storage",
    "Microsoft.Security",
    "Microsoft.SecurityInsights",
  ]

  # General locals
  diagnostics_setting_name = "terraform-managed-diagnostics"

  # Cross-validation for geo_region_mapping against environments
  invalid_dns_environments = [
    for item in flatten(flatten(var.geo_region_mapping[*].regions[*].environments[*].network.dns_environment)) : item
    if !contains(var.environments, item)
  ]

  # Cross-validation for denied resource types against allowed resource providers
  invalid_denied_resource_types = [
    for item in var.denied_resource_types : item
    if !contains(var.allowed_resource_providers, split("/", item)[0])
  ]

  # Geo locals
  geos_list = var.geo_region_mapping[*].geo_name
  geos_details = {
    for geo_item in var.geo_region_mapping :
    geo_item.geo_name => {
      geo_platform_subscription_id = geo_item.geo_platform_subscription_id
      geo_platform_location        = geo_item.geo_platform_location
      geo_region_names             = geo_item.regions[*].azure_region_name
    }
  } # Location locals
  locations_list = flatten([
    for geo_item in var.geo_region_mapping : [
      geo_item.regions[*].azure_region_name
    ]
  ])
  locations_details = merge([
    for geo_item in var.geo_region_mapping : {
      for region_item in geo_item.regions :
      region_item.azure_region_name => {
        geo_name                     = geo_item.geo_name
        geo_platform_subscription_id = geo_item.geo_platform_subscription_id
        geo_platform_location        = geo_item.geo_platform_location
        environments                 = region_item.environments
      }
    }
  ]...)

  # Environment locals
  environments_details = merge(flatten([
    for geo_item in var.geo_region_mapping : [
      for region_item in geo_item.regions : {
        for environment_item in region_item.environments :
        "${region_item.azure_region_name}-${environment_item.environment_name}" => {
          geo_name                     = geo_item.geo_name
          geo_platform_subscription_id = geo_item.geo_platform_subscription_id
          geo_platform_location        = geo_item.geo_platform_location
          azure_region_name            = region_item.azure_region_name
          environment_name             = environment_item.environment_name
          network                      = environment_item.network
        }
      }
    ]
  ])...)
}

locals {
  # Platform subscription ids - network
  subscription_ids_network = distinct([
    for key, value in local.environments_details :
    value.network.subscription_id
  ])

  # Platform subscription ids - management
  subscription_ids_management = distinct([
    for key, value in local.geos_details :
    value.geo_platform_subscription_id
  ])

  subscription_ids_all = distinct(
    concat(
      [var.global_platform_subscription_id],
      local.subscription_ids_network,
      local.subscription_ids_management,
    )
  )
}

locals {
  # Network manager connectivity configuration list
  network_manager_connectivity_configuration_ids = concat(flatten([
    for key, value in local.environments_details :
    # Only include environments that are NOT using Virtual WAN
    !try(value.network.enable_virtual_wan, false) ?
    module.file_new_environment[key].network_manager_connectivity_configuration_ids :
    []
  ]), module.file_new_tenant.network_manager_connectivity_configuration_ids)

  # Network manager security admin configuration presence flags
  # These can be determined at plan time without depending on resource IDs
  has_tenant_security_config = var.deploy_test_vms # Only true when TiP is deployed
  has_vwan_security_config   = var.enable_virtual_wan
  has_intent_security_config = try(var.intent_layer.enabled, false) && try(var.intent_layer.deploy_azure_intent, false)

  # Keep the original variable for backward compatibility (used by other modules)
  # Combine security admin configurations from all modules and remove duplicates
  network_manager_security_admin_configuration_ids = distinct(compact(concat(
    local.has_tenant_security_config ? module.file_new_tenant.network_manager_security_admin_configuration_ids : [],
    local.has_vwan_security_config && length(module.virtual_wan) > 0 ?
    module.virtual_wan[0].network_manager_security_admin_configuration_ids : [],
    local.has_intent_security_config && length(module.intent_layer) > 0 ?
    [module.intent_layer[0].azure_security_admin_configuration_id] : []
  )))

  # Network manager routing configuration list
  network_manager_routing_configuration_ids = concat(flatten([
    for key, value in local.environments_details :
    # Only include environments that are NOT using Virtual WAN
    !try(value.network.enable_virtual_wan, false) ?
    module.file_new_environment[key].network_manager_routing_configuration_ids :
    []
  ]), [])
}

locals {
  # Network hub list - List contains one object for each network hub containing information about the vnet, environment and region
  # Only include traditional hub-spoke environments (not Virtual WAN environments)
  network_hub_details = [
    for key, value in local.environments_details :
    {
      environment_name           = value.environment_name
      azure_region_name          = value.azure_region_name
      address_space_allocated    = value.network.address_space_allocated
      virtual_network_hub_id     = module.file_new_environment[key].virtual_network_hub_id
      address_space_network_hub  = value.network.address_space_network_hub
      azfw_ip_address            = module.file_new_environment[key].azfw_ip_address
      route_table_id_azfw_subnet = module.file_new_environment[key].route_table_azfw_subnet_id
    }
    # Only include environments that are NOT using Virtual WAN
    if !try(value.network.enable_virtual_wan, false)
  ]

  # Network hub peering map - Map contains one key value pair per network hub peering (source -> sink) to enable transitive connectivity
  virtual_network_hub_peerings = merge([
    # Loop through network hub detail list
    for source_idx, source_value in local.network_hub_details : {
      # Nested loop through network hub detail list to create peering list
      for sink_idx, sink_value in local.network_hub_details :
      "source-${source_value.environment_name}-${source_value.azure_region_name}-sink-${sink_value.environment_name}-${sink_value.azure_region_name}" => {
        virtual_network_id                   = source_value.virtual_network_hub_id,
        route_table_id_azfw_subnet           = source_value.route_table_id_azfw_subnet
        remote_address_space_allocated       = sink_value.address_space_allocated
        remote_virtual_network_id            = sink_value.virtual_network_hub_id,
        remote_virtual_network_address_space = sink_value.address_space_network_hub
        remote_azfw_ip_address               = sink_value.azfw_ip_address
      } if source_idx != sink_idx && source_value.environment_name == sink_value.environment_name # Filter out objects where the id is the same or where teh environment name is not equal
    }
  ]...)

  # Network hub routes map - Map contains all details to create global routing rules across hubs
  virtual_network_hub_routes = merge([
    # Loop through hub peering map
    for peerings_key, peerings_value in local.virtual_network_hub_peerings : {
      # Loop through allocated address space
      for address_space_index, address_space_value in peerings_value.remote_address_space_allocated :
      "${peerings_key}-${replace(replace(address_space_value, ".", "-"), "/", "-")}" => {
        route_table_id_azfw_subnet     = peerings_value.route_table_id_azfw_subnet
        remote_address_space_allocated = address_space_value
        remote_azfw_ip_address         = peerings_value.remote_azfw_ip_address
      }
    }
  ]...)
}

# Virtual WAN Locals - for replacing traditional hub-spoke architecture
locals {
  # Virtual WAN Hub configuration from environment details
  virtual_wan_hubs = var.enable_virtual_wan ? {
    for key, value in local.environments_details : key => {
      location       = value.azure_region_name
      environment    = value.environment_name
      address_prefix = value.network.virtual_hub_address_space != null ? value.network.virtual_hub_address_space : cidrsubnet(value.network.address_space_network_hub, 1, 0)
      # Hub type based on secure hub deployment setting
      hub_type                    = var.deploy_secure_hubs ? "secure" : "standard"
      enable_expressroute_gateway = try(value.network.enable_expressroute_gateway, true)
      expressroute_scale_units    = try(value.network.expressroute_scale_units, 1)
      enable_vpn_gateway          = try(value.network.enable_vpn_gateway, false)
      vpn_scale_units             = try(value.network.vpn_scale_units, 1)
      # Secure hub deployment control - Azure Firewall only deployed when deploy_secure_hubs is true
      enable_firewall          = var.deploy_secure_hubs ? try(value.network.enable_azure_firewall, true) : false
      firewall_sku             = var.deploy_secure_hubs ? try(value.network.azure_firewall_sku, "Standard") : null
      firewall_policy_id       = var.deploy_secure_hubs ? null : null # Will be populated after firewall policies are created
      firewall_public_ip_count = var.deploy_secure_hubs ? try(value.network.azure_firewall_public_ip_count, 1) : 0
      # Routing intent requires secure hub (Azure Firewall)
      enable_routing_intent = var.deploy_secure_hubs ? try(value.network.enable_routing_intent, true) : false
    } if try(value.network.enable_virtual_wan, false)
  } : {}

  # Firewall policies for Virtual WAN hubs - only created when secure hubs are enabled
  virtual_wan_firewall_policies = var.enable_virtual_wan && var.deploy_secure_hubs ? {
    for env in distinct([
      for key, value in local.environments_details : value.environment_name
      if try(value.network.enable_virtual_wan, false)
      ]) : env => {
      location    = var.location                                                # Use primary location for policies
      sku         = env == "prod" || env == "production" ? "Standard" : "Basic" # Cost-optimized SKUs without Premium features
      dns_servers = []                                                          # Can be customized per environment
    }
  } : {}

  # Virtual WAN resource group configuration
  virtual_wan_resource_groups = var.enable_virtual_wan ? {
    "vwan" = {
      name     = "rg-network-vwan-${var.suffix}"
      location = var.location
      tags = merge(var.tags, {
        Purpose = "Virtual-WAN-Infrastructure"
      })
    }
  } : {}

  # AWS Region Mapping for Intent Layer Multi-Cloud Support
  # Maps Azure regions to corresponding AWS regions
  aws_region_mapping = {
    "eastus"             = "us-east-1"
    "eastus2"            = "us-east-1"
    "westus"             = "us-west-1"
    "westus2"            = "us-west-2"
    "westus3"            = "us-west-2"
    "centralus"          = "us-east-1"
    "northcentralus"     = "us-east-1"
    "southcentralus"     = "us-east-1"
    "westcentralus"      = "us-west-2"
    "canadacentral"      = "ca-central-1"
    "canadaeast"         = "ca-central-1"
    "brazilsouth"        = "sa-east-1"
    "northeurope"        = "eu-north-1"
    "westeurope"         = "eu-west-1"
    "uksouth"            = "eu-west-2"
    "ukwest"             = "eu-west-2"
    "francecentral"      = "eu-west-3"
    "francesouth"        = "eu-west-3"
    "germanywestcentral" = "eu-central-1"
    "germanynorth"       = "eu-central-1"
    "switzerlandnorth"   = "eu-central-1"
    "switzerlandwest"    = "eu-central-1"
    "norwayeast"         = "eu-north-1"
    "norwaywest"         = "eu-north-1"
    "swedencentral"      = "eu-north-1"
    "southeastasia"      = "ap-southeast-1"
    "eastasia"           = "ap-southeast-1"
    "australiaeast"      = "ap-southeast-2"
    "australiasoutheast" = "ap-southeast-2"
    "australiacentral"   = "ap-southeast-2"
    "australiacentral2"  = "ap-southeast-2"
    "japaneast"          = "ap-northeast-1"
    "japanwest"          = "ap-northeast-1"
    "koreacentral"       = "ap-northeast-2"
    "koreasouth"         = "ap-northeast-2"
    "southindia"         = "ap-south-1"
    "westindia"          = "ap-south-1"
    "centralindia"       = "ap-south-1"
    "uaenorth"           = "me-south-1"
    "uaecentral"         = "me-south-1"
    "southafricanorth"   = "af-south-1"
    "southafricawest"    = "af-south-1"
  }
}
