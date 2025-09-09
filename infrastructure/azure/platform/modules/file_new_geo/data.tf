data "azurerm_client_config" "current" {}

data "azapi_resource_action" "resource_provider" {
  for_each = toset(var.allowed_resource_providers)

  type        = "${each.key}@2021-04-01"
  resource_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/${each.key}"

  action = null
  method = "GET"
  body   = null

  response_export_values = ["*"]
}

data "azurerm_monitor_diagnostic_categories" "diagnostic_categories_log_analytics_workspace" {
  resource_id = azapi_resource.log_analytics_workspace.id
}

data "azurerm_monitor_diagnostic_categories" "diagnostic_categories_network_manager" {
  resource_id = var.network_manager_resource_id
}
