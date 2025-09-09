# Platform subscription associations

# Global platform subscription association - move to Connectivity management group
resource "azurerm_management_group_subscription_association" "global_platform_subscription" {
  management_group_id = azurerm_management_group.management_group_connectivity.id
  subscription_id     = "/subscriptions/${var.global_platform_subscription_id}"

  depends_on = [
    time_sleep.sleep_management_groups
  ]
}

resource "azurerm_management_group_subscription_association" "connectivity_subscriptions" {
  for_each = toset(var.subscription_ids_connectivity)

  management_group_id = azurerm_management_group.management_group_connectivity.id
  subscription_id     = "/subscriptions/${each.value}"

  depends_on = [
    time_sleep.sleep_management_groups
  ]
}

resource "azurerm_management_group_subscription_association" "management_subscriptions" {
  for_each = toset(var.subscription_ids_management)

  management_group_id = azurerm_management_group.management_group_management.id
  subscription_id     = "/subscriptions/${each.value}"

  depends_on = [
    time_sleep.sleep_management_groups
  ]
}
