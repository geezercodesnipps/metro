# Storage diagnostics
resource "azurerm_monitor_diagnostic_setting" "diagnostic_setting_storage" {
  name                       = var.diagnostics_setting_name
  target_resource_id         = azapi_resource.storage_account.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  dynamic "enabled_log" {
    iterator = entry
    for_each = data.azurerm_monitor_diagnostic_categories.diagnostic_categories_storage_account.log_category_groups
    content {
      category_group = entry.value
    }
  }

  dynamic "metric" {
    iterator = entry
    for_each = data.azurerm_monitor_diagnostic_categories.diagnostic_categories_storage_account.metrics
    content {
      category = entry.value
      enabled  = true
    }
  }
}
