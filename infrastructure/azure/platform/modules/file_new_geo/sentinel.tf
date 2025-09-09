resource "azapi_resource" "sentinel_log_analytics_workspace_onboarding" {
  count = var.enable_sentinel ? 1 : 0

  type      = "Microsoft.SecurityInsights/onboardingStates@2024-03-01"
  parent_id = azapi_resource.log_analytics_workspace.id
  name      = "default"

  body = {
    properties = {
      customerManagedKey = false
    }
  }

  response_export_values    = ["*"]
  schema_validation_enabled = true
  locks                     = []
  ignore_casing             = false
  ignore_missing_property   = false
}
