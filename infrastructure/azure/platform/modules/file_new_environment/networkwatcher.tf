# resource "azapi_resource" "network_watcher" {
#   type      = "Microsoft.Network/networkWatchers@2024-01-01"
#   parent_id = azapi_resource.resource_group_network_watcher.id
#   name      = "NetworkWatcher_${var.location}"
#   location  = var.location
#   tags      = var.tags

#   response_export_values    = ["*"]
#   schema_validation_enabled = true
#   locks                     = []
#   ignore_casing             = false
#   ignore_missing_property   = false
# }
