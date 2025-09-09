resource "azapi_resource" "virtual_network_hub_flow_logs" {
  type      = "Microsoft.Network/networkWatchers/flowLogs@2024-01-01"
  parent_id = "/subscriptions/${var.environment_network_subscription_id}/resourceGroups/NetworkWatcherRG/providers/Microsoft.Network/networkwatchers/NetworkWatcher_${var.location}"
  name      = "${azapi_resource.virtual_network_hub.name}-flowlog"
  location  = var.location
  tags      = var.tags

  body = {
    properties = {
      storageId        = var.storage_account_id
      targetResourceId = azapi_resource.virtual_network_hub.id
      enabled          = true
      flowAnalyticsConfiguration = {
        networkWatcherFlowAnalyticsConfiguration = {
          enabled                  = true
          trafficAnalyticsInterval = 60
          workspaceResourceId      = var.log_analytics_workspace_id
        }
      }
      format = {
        type    = "JSON"
        version = 2
      }
      retentionPolicy = {
        enabled = true
        days    = 7
      }
    }
  }

  response_export_values    = ["*"]
  schema_validation_enabled = true
  locks                     = []
  ignore_casing             = false
  ignore_missing_property   = false

  # depends_on = [
  #   azapi_resource.network_watcher
  # ]
}
