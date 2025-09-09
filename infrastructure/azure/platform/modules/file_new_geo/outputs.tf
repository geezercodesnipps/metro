output "management_group_prod_id" {
  description = "Specifies the id of the prod management group."
  value       = azurerm_management_group.management_group_prod.id
  sensitive   = false
}

output "management_group_non_prod_id" {
  description = "Specifies the id of the non-prod management group."
  value       = azurerm_management_group.management_group_non_prod.id
  sensitive   = false
}

output "log_analytics_workspace_id" {
  description = "Specifies the resource id of the log analytics workspace of the geo."
  value       = azapi_resource.log_analytics_workspace.id
  sensitive   = false
}
