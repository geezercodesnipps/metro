resource "azurerm_role_assignment" "management_group_owner" {
  description          = "Role assignment required for management group owner."
  scope                = azurerm_management_group.management_group_root.id
  role_definition_name = "Contributor"
  principal_id         = data.azurerm_client_config.this.object_id
  principal_type       = "ServicePrincipal"

  depends_on = [
    time_sleep.sleep_provider_registration_mg,
    azurerm_management_group.management_group_root
  ]
}

resource "azurerm_role_assignment" "management_group_policy_contributor" {
  description          = "Role assignment required for policy assignment operations."
  scope                = azurerm_management_group.management_group_root.id
  role_definition_name = "Resource Policy Contributor"
  principal_id         = data.azurerm_client_config.this.object_id
  principal_type       = "ServicePrincipal"

  depends_on = [
    time_sleep.sleep_provider_registration_mg,
    azurerm_management_group.management_group_root
  ]
}

resource "azurerm_role_assignment" "management_group_policy_contributor_landing_zones" {
  description          = "Role assignment required for policy assignment operations on landing zones."
  scope                = azurerm_management_group.management_group_landing_zones.id
  role_definition_name = "Resource Policy Contributor"
  principal_id         = data.azurerm_client_config.this.object_id
  principal_type       = "ServicePrincipal"

  depends_on = [
    time_sleep.sleep_provider_registration_mg,
    azurerm_management_group.management_group_landing_zones
  ]
}

# Note: Owner role assignment already exists in Azure, managing via import or external process
