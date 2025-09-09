resource "azapi_resource" "user_assigned_identity" {
  type      = "Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31"
  parent_id = azurerm_resource_group.resource_group_identity.id
  name      = "id-${local.suffix}"
  location  = var.location
  tags      = var.tags

  response_export_values    = ["*"]
  schema_validation_enabled = true
  locks                     = []
  ignore_casing             = false
  ignore_missing_property   = false
}
