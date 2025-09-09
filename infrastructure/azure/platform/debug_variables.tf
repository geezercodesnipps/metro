# Debug output to check variables
output "debug_environments_details" {
  value = {
    for key, value in local.environments_details :
    key => {
      azure_region_name                    = value.azure_region_name
      environment_name                     = value.environment_name
      azfw_sku                             = value.network.azfw_sku
      network_keys                         = keys(value.network)
      has_management_subnet                = contains(keys(value.network), "address_space_azfw_management_subnet")
      management_subnet_raw                = lookup(value.network, "address_space_azfw_management_subnet", "NOT_FOUND")
      address_space_azfw_management_subnet = try(value.network.address_space_azfw_management_subnet, "EMPTY_TRY")
    }
  }
}
