resource "azurerm_private_dns_zone" "private_dns_zone" {
  provider = azurerm.network

  for_each = local.private_dns_zones_per_environment

  name                = each.value.dns_name
  resource_group_name = azurerm_resource_group.resource_group_private_dns[each.value.environment_name].name
}
