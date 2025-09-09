module "artifacts_management_group_root" {
  source = "../artifacts"

  providers = {
    azurerm = azurerm
  }

  location                       = var.location
  deployment_scope               = azurerm_management_group.management_group_root.id
  azure_resources_library_folder = "${path.module}/../../definitions"
  custom_role_suffix             = local.suffix
  custom_template_variables = {
    # Management scope variables
    scope_id_root          = "/providers/Microsoft.Management/managementGroups/${azurerm_management_group.management_group_root.name}"
    scope_id_platform      = "/providers/Microsoft.Management/managementGroups/${azurerm_management_group.management_group_platform.name}"
    scope_id_management    = "/providers/Microsoft.Management/managementGroups/${azurerm_management_group.management_group_management.name}"
    scope_id_connectivity  = "/providers/Microsoft.Management/managementGroups/${azurerm_management_group.management_group_connectivity.name}"
    scope_id_landing_zones = "/providers/Microsoft.Management/managementGroups/${azurerm_management_group.management_group_landing_zones.name}"
    scope_id_playground    = "/providers/Microsoft.Management/managementGroups/${azurerm_management_group.management_group_playground.name}"
    scope_id_decomissioned = "/providers/Microsoft.Management/managementGroups/${azurerm_management_group.management_group_decomissioned.name}"
  }

  depends_on = [
    time_sleep.sleep_management_groups
  ]
}

# TODO: Assign Global Initaitives to the respective scopes
