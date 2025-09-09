location                                        = "westeurope"
suffix                                          = "FSI38"
environments                                    = ["dev"] # ["uat", "prd"]
tags                                            = {}
organization_name                               = "ADIA"
global_platform_subscription_id                 = "4f007f2c-5c8d-4a59-8f0c-9d194c1ed152"
owner                                          = ""
enable_ddos_protection_plan                     = false
enable_sentinel                                 = false
enable_management_group_settings_update         = false
enable_cloud_security_benchmark_settings_update = true

# Virtual WAN Configuration - Global flag to enable Virtual WAN module
# GLOBAL: Deploy Virtual WAN infrastructure
enable_virtual_wan = true  

# Test Infrastructure Provisioning (TiP) - Controlled by pipeline parameter
# This will be overridden by the pipeline's deployTestVMs parameter
deploy_test_vms = true
 

# Required variables for deployment
management_group_name = "adia"
admin_entra_id_group_object_id = "00000000-0000-0000-0000-000000000000"  # Replace with actual object ID
reader_entra_id_group_object_id = "00000000-0000-0000-0000-000000000000"  # Replace with actual object ID

# Billing configuration (set to null to skip subscription creation)
ea_billing_details = null
mca_billing_details = null

# Vnet spoke details
vnet_spoke_details = {
  enabled          = false
  name_prefix      = "spoke-vnet"
  address_prefixes = []
  dns_servers      = []
}

allowed_resource_providers = [
  "Microsoft.Network",
  "Microsoft.Storage"
]
denied_resource_types = [
  "Microsoft.Network/azureFirewalls",
  "Microsoft.Network/privateDnsZones"
]
geo_region_mapping = [
  {
    geo_name                     = "EMEA"
    geo_platform_subscription_id = "fbbce6e6-ff30-4bca-8895-c1d306b5de7f" 
    geo_platform_location        = "westeurope"
    regions = [
      {
        azure_region_name = "westeurope"
        environments = [
          {
            environment_name = "dev"
            network = {
              subscription_id = "c8e99e94-859c-46af-9907-a20b56753a2e"
              dns_environment = "dev"
              address_space_allocated = [
                "10.0.4.0/22",
                "172.32.0.0/12"
              ]
              # Traditional hub-spoke configuration (used when enable_virtual_wan = false)
              address_space_network_hub            = "10.0.4.0/22"
              address_space_gateway_subnet         = "10.0.4.0/26"
              address_space_azfw_subnet            = "10.0.4.64/26"
              address_space_azfw_management_subnet = "10.0.4.128/26"
              address_space_dns_inbound_subnet     = "10.0.4.192/26"
              address_space_dns_outbound_subnet    = "10.0.5.0/26"
              ergw_sku                             = "Standard"
              azfw_sku                             = "Basic"
              
              # Virtual WAN Configuration - Environment participation flag
              enable_virtual_wan           = true  # ENVIRONMENT: This specific environment uses Virtual WAN (vs traditional hub-spoke)
              virtual_hub_address_space    = "10.0.4.0/23"  # /23 recommended for Virtual WAN hubs
              enable_expressroute_gateway  = false
              expressroute_scale_units     = 1
              enable_vpn_gateway          = false
              vpn_scale_units             = 1
              enable_azure_firewall       = true
              azure_firewall_sku          = "Basic"
              azure_firewall_public_ip_count = 1
              enable_routing_intent       = true
              hub_routing_preference      = "ASPath"
            }
          }
        ]
      },
      {
        azure_region_name = "uaenorth"
        environments = [
          {
            environment_name = "dev"
            network = {
              subscription_id = "033b3671-da1a-427d-b9ca-576e6ad60771"
              dns_environment = "dev"
              address_space_allocated = [
                "10.1.4.0/22",
                "172.33.0.0/12"
              ]
              # Traditional hub-spoke configuration (used when enable_virtual_wan = false)
              address_space_network_hub            = "10.1.4.0/22"
              address_space_gateway_subnet         = "10.1.4.0/26"
              address_space_azfw_subnet            = "10.1.4.64/26"
              address_space_azfw_management_subnet = "10.1.4.128/26"
              address_space_dns_inbound_subnet     = "10.1.4.192/26"
              address_space_dns_outbound_subnet    = "10.1.5.0/26"
              ergw_sku                             = "Standard"
              azfw_sku                             = "Basic"
              
              # Virtual WAN Configuration - Environment participation flag
              enable_virtual_wan           = true  # ENVIRONMENT: This specific environment uses Virtual WAN (vs traditional hub-spoke)
              virtual_hub_address_space    = "10.1.4.0/23"  # /23 recommended for Virtual WAN hubs
              enable_expressroute_gateway  = false
              expressroute_scale_units     = 1
              enable_vpn_gateway          = false
              vpn_scale_units             = 1
              enable_azure_firewall       = true
              azure_firewall_sku          = "Basic"
              azure_firewall_public_ip_count = 1
              enable_routing_intent       = true
              hub_routing_preference      = "ASPath"
            }
          }
        ]
      }
    ]
  }
]

