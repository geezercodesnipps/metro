# Top-level Management Group with enhanced timeout and retry
resource "azurerm_management_group" "management_group_root" {
  name             = "${local.suffix}-${lower(var.organization_name)}"
  display_name     = var.organization_name
  subscription_ids = []

  timeouts {
    create = "30m"
    read   = "10m"
    update = "20m"
    delete = "20m"
  }
}

# Sleep to ensure root management group is fully propagated before creating child groups
resource "time_sleep" "sleep_after_root_mg" {
  create_duration = "180s"  # 3 minutes for root MG propagation
  
  depends_on = [
    azurerm_management_group.management_group_root
  ]
}

# Platform Management Group - parent for all platform-related groups
resource "azurerm_management_group" "management_group_platform" {
  parent_management_group_id = azurerm_management_group.management_group_root.id
  name                       = "${local.suffix}-platform"
  display_name               = "Platform"
  subscription_ids           = []

  timeouts {
    create = "20m"
    read   = "10m"
    update = "15m"
    delete = "15m"
  }
  
  depends_on = [
    time_sleep.sleep_after_root_mg
  ]
}

# Sleep to ensure platform management group is fully propagated before creating child groups
resource "time_sleep" "sleep_platform_management_group" {
  create_duration = "60s"
  
  depends_on = [
    azurerm_management_group.management_group_platform
  ]
}

# Management Group for management subscriptions
resource "azurerm_management_group" "management_group_management" {
  parent_management_group_id = azurerm_management_group.management_group_platform.id
  name                       = "${local.suffix}-management"
  display_name               = "Management"
  subscription_ids           = []

  timeouts {
    create = "20m"
    read   = "10m"
    update = "15m"
    delete = "15m"
  }
  
  depends_on = [
    time_sleep.sleep_platform_management_group
  ]
}

# Management Group for connectivity subscriptions
resource "azurerm_management_group" "management_group_connectivity" {
  parent_management_group_id = azurerm_management_group.management_group_platform.id
  name                       = "${local.suffix}-connectivity"
  display_name               = "Connectivity"
  subscription_ids           = []

  timeouts {
    create = "20m"
    read   = "10m"
    update = "15m"
    delete = "15m"
  }
  
  depends_on = [
    time_sleep.sleep_platform_management_group
  ]
}

# Landing Zone Management Group
resource "azurerm_management_group" "management_group_landing_zones" {
  parent_management_group_id = azurerm_management_group.management_group_root.id
  name                       = "${local.suffix}-landingzones"
  display_name               = "Landing Zones"
  subscription_ids           = []

  timeouts {
    create = "20m"
    read   = "10m"
    update = "15m"
    delete = "15m"
  }
  
  depends_on = [
    time_sleep.sleep_after_root_mg
  ]
}

# Management Group for Playground subscriptions  
resource "azurerm_management_group" "management_group_playground" {
  parent_management_group_id = azurerm_management_group.management_group_root.id
  name                       = "${local.suffix}-playground"
  display_name               = "Playground"
  subscription_ids           = []

  timeouts {
    create = "20m"
    read   = "10m"
    update = "15m"
    delete = "15m"
  }
  
  depends_on = [
    time_sleep.sleep_after_root_mg
  ]
}

# Management Group for Decommissioned subscriptions  
resource "azurerm_management_group" "management_group_decomissioned" {
  parent_management_group_id = azurerm_management_group.management_group_root.id
  name                       = "${local.suffix}-decommissioned"
  display_name               = "Decommissioned"
  subscription_ids           = []

  timeouts {
    create = "20m"
    read   = "10m"
    update = "15m"
    delete = "15m"
  }
  
  depends_on = [
    time_sleep.sleep_after_root_mg
  ]
}

# Sleep resource to allow management groups to be fully created before other resources depend on them
resource "time_sleep" "sleep_management_groups" {
  create_duration = "30s"
  
  depends_on = [
    azurerm_management_group.management_group_root,
    azurerm_management_group.management_group_platform,
    azurerm_management_group.management_group_management,
    azurerm_management_group.management_group_connectivity,
    azurerm_management_group.management_group_landing_zones,
    azurerm_management_group.management_group_playground,
    azurerm_management_group.management_group_decomissioned
  ]
}

# Register Resource Providers to the Management Group
resource "null_resource" "provider_registration_mg" {
  for_each = toset(local.resource_providers_mg)

  triggers = {}
  provisioner "local-exec" {
    command = "az provider register --namespace ${each.key} --management-group-id ${azurerm_management_group.management_group_root.name}"
  }
  
  depends_on = [
    time_sleep.sleep_management_groups
  ]
}

# Sleep resource to allow provider registration to complete
resource "time_sleep" "sleep_provider_registration_mg" {
  create_duration = "120s"  # Increased from 30s to 120s
  
  depends_on = [
    null_resource.provider_registration_mg
  ]
}
