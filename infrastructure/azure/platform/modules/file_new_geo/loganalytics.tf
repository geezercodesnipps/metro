resource "azapi_resource" "log_analytics_workspace" {
  type      = "Microsoft.OperationalInsights/workspaces@2023-09-01"
  parent_id = azurerm_resource_group.resource_group_logs.id
  name      = "log-${local.suffix}"
  location  = var.location
  tags      = var.tags

  body = {
    properties = {
      features = {
        disableLocalAuth                            = false
        enableLogAccessUsingOnlyResourcePermissions = true
      }
      publicNetworkAccessForIngestion = "Enabled"
      publicNetworkAccessForQuery     = "Enabled"
      retentionInDays                 = 30  # Minimum for PerGB2018 SKU
      sku = {
        name = "PerGB2018"  # Using standard pricing tier as Free tier is no longer available for new workspaces
      }
    }
  }

  response_export_values    = ["*"]
  schema_validation_enabled = true
  locks                     = []
  ignore_casing             = false
  ignore_missing_property   = false
}
