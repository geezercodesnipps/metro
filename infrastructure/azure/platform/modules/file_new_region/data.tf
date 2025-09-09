data "azurerm_monitor_diagnostic_categories" "diagnostic_categories_storage_account" {
  resource_id = azapi_resource.storage_account.id
}
