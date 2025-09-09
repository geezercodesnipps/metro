# Import blocks for existing policy-created diagnostic settings
# This prevents "resource already exists" errors during deployment

# NOTE: Import blocks must be placed in the root module (infrastructure/platform/imports.tf)
# This file serves as documentation for the imports needed for this module

# Required imports for this module:
# 1. Log Analytics workspace diagnostic setting created by Azure Policy:
#    terraform import 'module.file_new_geo["EMEA"].azurerm_monitor_diagnostic_setting.diagnostic_setting_log_analytics_workspace' '/subscriptions/fbbce6e6-ff30-4bca-8895-c1d306b5de7f/resourceGroups/rg-logs-fsi-emea/providers/Microsoft.OperationalInsights/workspaces/log-fsi-emea|setByPolicy-LogAnalytics'
#
# 2. Network Manager diagnostic setting (if exists):
#    terraform import 'module.file_new_geo["EMEA"].azurerm_monitor_diagnostic_setting.diagnostic_setting_network_manager' '<network-manager-resource-id>|setByPolicy-LogAnalytics'
