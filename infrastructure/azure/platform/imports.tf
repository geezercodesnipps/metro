# Import blocks for existing policy-created resources
# Currently not needed - diagnostic settings are managed by Azure Policy instead

# Note: If you need to import policy-created resources in the future:
# 1. Uncomment the appropriate import block below
# 2. Run terraform apply to import
# 3. Comment out the import block again after successful import

# Example import block for EMEA diagnostic setting:
# import {
#   to = module.file_new_geo["EMEA"].azurerm_monitor_diagnostic_setting.diagnostic_setting_log_analytics_workspace
#   id = "/subscriptions/fbbce6e6-ff30-4bca-8895-c1d306b5de7f/resourceGroups/rg-logs-fsi-emea/providers/Microsoft.OperationalInsights/workspaces/log-fsi-emea|setByPolicy-LogAnalytics"
# }

# DISABLED: Import existing ERGW diagnostic setting - not needed since we're not creating them in Terraform
# import {
#   to = module.file_new_environment["westeurope-dev"].azurerm_monitor_diagnostic_setting.diagnostic_setting_ergw
#   id = "/subscriptions/c8e99e94-859c-46af-9907-a20b56753a2e/resourceGroups/rg-network-adia-dev-westeurope/providers/Microsoft.Network/virtualNetworkGateways/ergw-adia-dev-westeurope|terraform-managed-diagnostics"
# }
