resource "azurerm_private_dns_zone_virtual_network_link" "private_dns_zone_virtual_network_links" {
  provider = azurerm.global_network

  for_each = var.private_dns_zone_ids

  name                = "${each.key}-${local.suffix}"
  resource_group_name = each.value.resource_group_name
  tags                = var.tags

  private_dns_zone_name = each.value.name
  virtual_network_id    = azapi_resource.virtual_network_hub.id
}
