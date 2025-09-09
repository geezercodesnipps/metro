resource "azurerm_resource_group" "resource_group_logs" {
  name     = "rg-logs-${local.suffix}"
  location = var.location
  tags     = var.tags

  # Prevent accidental deletion of existing resource groups
  # lifecycle {
  #   prevent_destroy = true
  # }
}
