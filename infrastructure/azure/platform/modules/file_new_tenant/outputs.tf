output "management_group_root_id" {
  description = "Specifies the id of the root management group."
  value       = azurerm_management_group.management_group_root.id
  sensitive   = false
}

output "management_group_landing_zones_id" {
  description = "Specifies the id of the langing zone management group."
  value       = azurerm_management_group.management_group_landing_zones.id
  sensitive   = false
}

output "management_group_platform_id" {
  description = "Specifies the id of the platform management group."
  value       = azurerm_management_group.management_group_platform.id
  sensitive   = false
}

output "private_dns_zone_ids" {
  description = "Specifies the ids of the private dns zones per environment."
  value       = local.private_dns_zone_details_per_environment
  sensitive   = false
}

output "network_manager_resource_id" {
  description = "Specifies the Azure Virtual Network Manager resource id."
  value       = azurerm_network_manager.network_manager.id
  sensitive   = false
}

output "network_manager_connectivity_configuration_ids" {
  description = "Specifies the IDs of the network manager connectivity configurations."
  value = [
    for item in var.environments :
    azurerm_network_manager_connectivity_configuration.global_hub_vnets_mesh[item].id
  ]
  sensitive = false
}

output "network_manager_security_admin_configuration_ids" {
  description = "Specifies the IDs of the network manager security admin configurations."
  value = var.deploy_test_vms ? [
    azurerm_network_manager_security_admin_configuration.network_manager_security_admin_configuration_spoke_vnets[0].id
  ] : []
  sensitive = false

  depends_on = [
    time_sleep.sleep_network_manager_security_admin_configurations
  ]
}

output "network_manager_spoke_group_id" {
  description = "ID of the Network Manager spoke VNets network group for adding static members"
  value = azurerm_network_manager_network_group.network_manager_network_group_spoke_vnets.id
  sensitive = false
}

output "artifacts_management_group_root_setup_completed" {
  description = "Specifies whether the policy deployment at the root management group has completed successfully."
  value       = module.artifacts_management_group_root.artifacts_setup_completed
  sensitive   = false
}

output "network_ddos_protection_plan_id" {
  description = "Specifies the resource Id of the Azure DDoS protection plan."
  value       = var.enable_ddos_protection_plan ? one(azurerm_network_ddos_protection_plan.network_ddos_protection_plan[*].id) : ""
  sensitive   = false
}
