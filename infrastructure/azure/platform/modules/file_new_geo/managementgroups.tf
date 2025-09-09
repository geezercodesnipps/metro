# Landing Zone Management Groups - Direct under Landing Zones
resource "azurerm_management_group" "management_group_prod" {
  parent_management_group_id = var.management_group_landing_zones_id
  name                       = "prod"
  display_name               = "Prod"
  subscription_ids           = []
}

resource "azurerm_management_group" "management_group_non_prod" {
  parent_management_group_id = var.management_group_landing_zones_id
  name                       = "non-prod"
  display_name               = "Non-Prod"
  subscription_ids           = []
}

# Sleep because of replication lag within Azure
resource "time_sleep" "sleep_management_groups" {
  create_duration = "120s"

  depends_on = [
    azurerm_management_group.management_group_prod,
    azurerm_management_group.management_group_non_prod,
  ]
}
