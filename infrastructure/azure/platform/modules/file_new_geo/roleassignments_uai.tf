resource "azurerm_role_assignment" "uai_role_assignment_contributor" {
  description          = "Role assignment required for deployIfNotExists policies."
  scope                = var.management_group_landing_zones_id
  role_definition_name = "Contributor"
  principal_id         = try(jsondecode(azapi_resource.user_assigned_identity.output).properties.principalId, azapi_resource.user_assigned_identity.output.properties.principalId)
  principal_type       = "ServicePrincipal"

  depends_on = [
    time_sleep.sleep_management_groups,
  ]
}

# TODO: Add additional role assignments to platform resources
