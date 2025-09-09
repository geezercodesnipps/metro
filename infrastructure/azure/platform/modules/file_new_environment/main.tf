resource "azapi_resource" "resource_group_network_hub" {
  type      = "Microsoft.Resources/resourceGroups@2024-03-01"
  parent_id = "/subscriptions/${var.environment_network_subscription_id}"
  name      = "rg-network-${local.suffix}"
  location  = var.location
  tags      = var.tags

  response_export_values    = ["*"]
  schema_validation_enabled = true
  locks                     = []
  ignore_casing             = false
  ignore_missing_property   = false
}

# resource "azapi_resource" "resource_group_network_watcher" {
#   type      = "Microsoft.Resources/resourceGroups@2024-03-01"
#   parent_id = "/subscriptions/${var.environment_network_subscription_id}"
#   name      = "NetworkWatcherRG"
#   location  = var.location
#   tags      = var.tags

#   response_export_values    = ["*"]
#   schema_validation_enabled = true
#   locks                     = []
#   ignore_casing             = false
#   ignore_missing_property   = false
# }
