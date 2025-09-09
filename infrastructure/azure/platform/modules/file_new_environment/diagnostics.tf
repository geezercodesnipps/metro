# DISABLED: Firewall diagnostics - Managed by Azure Policy instead
# resource "azurerm_monitor_diagnostic_setting" "diagnostic_setting_log_analytics_workspace" {
#   name                       = "terraform-firewall-diagnostics"  # Use unique name to avoid policy conflicts
#   target_resource_id         = azapi_resource.firewall.id
#   log_analytics_workspace_id = var.log_analytics_workspace_id
#
#   dynamic "enabled_log" {
#     iterator = entry
#     for_each = data.azurerm_monitor_diagnostic_categories.diagnostic_categories_firewall.log_category_groups
#     content {
#       category_group = entry.value
#     }
#   }
#
#   dynamic "metric" {
#     iterator = entry
#     for_each = data.azurerm_monitor_diagnostic_categories.diagnostic_categories_firewall.metrics
#     content {
#       category = entry.value
#       enabled  = true
#     }
#   }
# }

# DISABLED: ERGW diagnostics - Managed by Azure Policy instead
# The "Compliant-Network" policy assignment creates these diagnostic settings with "DeployIfNotExists" effect
# resource "azurerm_monitor_diagnostic_setting" "diagnostic_setting_ergw" {
#   name                       = var.diagnostics_setting_name
#   target_resource_id         = azapi_resource.ergw.id
#   log_analytics_workspace_id = var.log_analytics_workspace_id
#
#   dynamic "enabled_log" {
#     iterator = entry
#     for_each = data.azurerm_monitor_diagnostic_categories.diagnostic_categories_ergw.log_category_groups
#     content {
#       category_group = entry.value
#     }
#   }
#
#   dynamic "metric" {
#     iterator = entry
#     for_each = data.azurerm_monitor_diagnostic_categories.diagnostic_categories_ergw.metrics
#     content {
#       category = entry.value
#       enabled  = true
#     }
#   }
#
#   lifecycle {
#     ignore_changes = all
#   }
# }

# DISABLED: Public IP diagnostics - Managed by Azure Policy instead
# resource "azurerm_monitor_diagnostic_setting" "diagnostic_setting_public_ip_ergw" {
#   name                       = var.diagnostics_setting_name
#   target_resource_id         = azapi_resource.public_ip_ergw.id
#   log_analytics_workspace_id = var.log_analytics_workspace_id
#
#   dynamic "enabled_log" {
#     iterator = entry
#     for_each = data.azurerm_monitor_diagnostic_categories.diagnostic_categories_public_ip.log_category_groups
#     content {
#       category_group = entry.value
#     }
#   }
#
#   dynamic "metric" {
#     iterator = entry
#     for_each = data.azurerm_monitor_diagnostic_categories.diagnostic_categories_public_ip.metrics
#     content {
#       category = entry.value
#       enabled  = true
#     }
#   }
# }

# DISABLED: Azure Firewall Public IP diagnostics - Managed by Azure Policy instead
# resource "azurerm_monitor_diagnostic_setting" "diagnostic_setting_public_ip_azfw" {
#   name                       = var.diagnostics_setting_name
#   target_resource_id         = azapi_resource.public_ip_azfw.id
#   log_analytics_workspace_id = var.log_analytics_workspace_id
#
#   dynamic "enabled_log" {
#     iterator = entry
#     for_each = data.azurerm_monitor_diagnostic_categories.diagnostic_categories_public_ip.log_category_groups
#     content {
#       category_group = entry.value
#     }
#   }
#
#   dynamic "metric" {
#     iterator = entry
#     for_each = data.azurerm_monitor_diagnostic_categories.diagnostic_categories_public_ip.metrics
#     content {
#       category = entry.value
#       enabled  = true
#     }
#   }
# }

# DISABLED: NSG diagnostics - Managed by Azure Policy instead
# The "Compliant-Network" policy assignment creates these diagnostic settings with "DeployIfNotExists" effect
# resource "azurerm_monitor_diagnostic_setting" "diagnostic_setting_nsg_dns_resolver_inbound" {
#   name                       = var.diagnostics_setting_name
#   target_resource_id         = azapi_resource.nsg_dns_resolver_inbound.id
#   log_analytics_workspace_id = var.log_analytics_workspace_id
#
#   dynamic "enabled_log" {
#     iterator = entry
#     for_each = data.azurerm_monitor_diagnostic_categories.diagnostic_categories_nsg.log_category_groups
#     content {
#       category_group = entry.value
#     }
#   }
#
#   dynamic "metric" {
#     iterator = entry
#     for_each = data.azurerm_monitor_diagnostic_categories.diagnostic_categories_nsg.metrics
#     content {
#       category = entry.value
#       enabled  = true
#     }
#   }
# }

# DISABLED: NSG Outbound diagnostics - Managed by Azure Policy instead
# resource "azurerm_monitor_diagnostic_setting" "diagnostic_setting_nsg_dns_resolver_outbound" {
#   name                       = var.diagnostics_setting_name
#   target_resource_id         = azapi_resource.nsg_dns_resolver_outbound.id
#   log_analytics_workspace_id = var.log_analytics_workspace_id
#
#   dynamic "enabled_log" {
#     iterator = entry
#     for_each = data.azurerm_monitor_diagnostic_categories.diagnostic_categories_nsg.log_category_groups
#     content {
#       category_group = entry.value
#     }
#   }
#
#   dynamic "metric" {
#     iterator = entry
#     for_each = data.azurerm_monitor_diagnostic_categories.diagnostic_categories_nsg.metrics
#     content {
#       category = entry.value
#       enabled  = true
#     }
#   }
# }

# DISABLED: Virtual network diagnostics - Managed by Azure Policy instead
# The "Compliant-Network" policy assignment creates these diagnostic settings with "DeployIfNotExists" effect
# resource "azurerm_monitor_diagnostic_setting" "diagnostic_setting_virtual_network_hub" {
#   name                       = var.diagnostics_setting_name
#   target_resource_id         = azapi_resource.virtual_network_hub.id
#   log_analytics_workspace_id = var.log_analytics_workspace_id
#
#   dynamic "enabled_log" {
#     iterator = entry
#     for_each = data.azurerm_monitor_diagnostic_categories.diagnostic_categories_virtual_network.log_category_groups
#     content {
#       category_group = entry.value
#     }
#   }
#
#   dynamic "metric" {
#     iterator = entry
#     for_each = data.azurerm_monitor_diagnostic_categories.diagnostic_categories_virtual_network.metrics
#     content {
#       category = entry.value
#       enabled  = true
#     }
#   }
# }
