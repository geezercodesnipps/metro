# Network Manager disgnostics
resource "azurerm_monitor_diagnostic_setting" "diagnostic_setting_network_manager" {
  name                       = "${var.diagnostics_setting_name}-${var.geo_name}"
  target_resource_id         = var.network_manager_resource_id
  log_analytics_workspace_id = azapi_resource.log_analytics_workspace.id

  lifecycle {
    ignore_changes = all
  }

  dynamic "enabled_log" {
    iterator = entry
    for_each = data.azurerm_monitor_diagnostic_categories.diagnostic_categories_network_manager.log_category_groups
    content {
      category_group = entry.value
    }
  }

  dynamic "metric" {
    iterator = entry
    for_each = data.azurerm_monitor_diagnostic_categories.diagnostic_categories_network_manager.metrics
    content {
      category = entry.value
      enabled  = true
    }
  }
}

# Log Analytics diagnostics - DISABLED to avoid conflicts with Azure Policy
# Azure Policy already manages diagnostic settings for Log Analytics workspaces
# Uncommenting this will cause conflicts with policy-created diagnostic settings
# resource "azurerm_monitor_diagnostic_setting" "diagnostic_setting_log_analytics_workspace" {
#   name                       = "terraform-managed-diagnostics"  # Use different name to avoid policy conflict
#   target_resource_id         = azapi_resource.log_analytics_workspace.id
#   log_analytics_workspace_id = azapi_resource.log_analytics_workspace.id
#
#   dynamic "enabled_log" {
#     iterator = entry
#     for_each = data.azurerm_monitor_diagnostic_categories.diagnostic_categories_log_analytics_workspace.log_category_groups
#     content {
#       category_group = entry.value
#     }
#   }
#
#   dynamic "metric" {
#     iterator = entry
#     for_each = data.azurerm_monitor_diagnostic_categories.diagnostic_categories_log_analytics_workspace.metrics
#     content {
#       category = entry.value
#       enabled  = true
#     }
#   }
#
#   lifecycle {
#     # Allow this resource to coexist with policy-created diagnostic settings
#     ignore_changes = [
#       enabled_log,
#       metric
#     ]
#   }
# }
