# Sleep resource to ensure management group is fully propagated before policy assignments
resource "time_sleep" "sleep_before_policy_assignments" {
  create_duration = "300s"  # 5 minutes wait for management group propagation
  
  depends_on = [
    time_sleep.sleep_provider_registration_mg
  ]
}

resource "azurerm_management_group_policy_assignment" "management_group_policy_assignment_mcsb" {
  name                 = "cloud-security-benchmark"
  policy_definition_id = "/providers/microsoft.authorization/policysetdefinitions/1f3afdf9-d0c9-4c3d-847f-89da613e70a8"
  management_group_id  = azurerm_management_group.management_group_root.id

  display_name = "Microsoft Cloud Security Benchmark Initiative"
  description  = "This policy initiative is a group of policies that provides all-up compliance view of the Microsoft Cloud Security Benchmark (MCSB) for Azure."
  enforce      = true
  metadata = jsonencode({
    version  = "57.43.0"
    category = "Security Center"
  })
  not_scopes = []
  parameters = jsonencode({
    autoProvisioningOfTheLogAnalyticsAgentShouldBeEnabledOnYourSubscriptionMonitoringEffect = {
      value = "Disabled"
    }
    useRbacRulesMonitoringEffect = {
      value = "Disabled"
    }
    vnetEnableDDoSProtectionMonitoringEffect = {
      value = "Disabled"
    }
    identityDesignateLessThanOwnersMonitoringEffect = {
      value = "Disabled"
    }
    sqlServersVirtualMachinesAdvancedDataSecurityMonitoringEffect = {
      value = "Disabled"
    }
    subscriptionsShouldHaveAContactEmailAddressForSecurityIssuesMonitoringEffect = {
      value = "Disabled"
    }
  })
  
  timeouts {
    create = "30m"
    read   = "15m" 
    update = "25m"
    delete = "20m"
  }
  
  depends_on = [
    time_sleep.sleep_before_policy_assignments
  ]
}

# Sleep resource to ensure policy assignment is fully propagated before exemption
resource "time_sleep" "sleep_after_mcsb_assignment" {
  create_duration = "120s"  # 2 minutes wait for policy assignment propagation
  
  depends_on = [
    azurerm_management_group_policy_assignment.management_group_policy_assignment_mcsb
  ]
}

resource "azurerm_management_group_policy_exemption" "management_group_policy_exemption_mcsb" {
  name                 = "cloud-security-benchmark"
  policy_assignment_id = azurerm_management_group_policy_assignment.management_group_policy_assignment_mcsb.id
  management_group_id  = azurerm_management_group.management_group_root.id

  display_name       = "Microsoft Cloud Security Benchmark Exemption"
  description        = "This policy exemption disables policies that are in conflict with platform capabilities and requirements."
  exemption_category = "Waiver"
  expires_on         = null
  metadata = jsonencode({
    version  = "57.43.0"
    category = "Security Center"
  })
  policy_definition_reference_ids = [
    "storageAccountShouldUseAPrivateLinkConnectionMonitoringEffect",
    "privateEndpointShouldBeConfiguredForKeyVaultMonitoringEffect",
  ]
  
  timeouts {
    create = "20m"
    read   = "10m"
    update = "15m"
    delete = "15m"
  }
  
  depends_on = [
    time_sleep.sleep_after_mcsb_assignment
  ]
}

resource "azurerm_management_group_policy_assignment" "management_group_policy_assignment_avnm_global_hubs" {
  for_each             = toset(var.environments)
  name                 = "avnm-global-hubs-${each.value}"
  policy_definition_id = azurerm_policy_definition.network_manager_global_hub_vnets_policy_definition[each.key].id
  management_group_id  = azurerm_management_group.management_group_root.id

  display_name = "Azure Virtual Network Manager global hubs (${each.value})"
  description  = "This policy assignment ensures global hub virtual networks are added to the global hubs network manager network group"
  enforce      = true
  metadata = jsonencode({
    category = "Azure Virtual Network Manager"
    version  = "1.0.0"
  })
  not_scopes = []
  
  timeouts {
    create = "30m"
    read   = "15m"
    update = "25m"
    delete = "20m"
  }
  
  depends_on = [
    time_sleep.sleep_before_policy_assignments
  ]
}

resource "azurerm_management_group_policy_assignment" "management_group_policy_assignment_avnm_spoke_vnets" {
  name                 = "avnm-spoke-vnets"
  policy_definition_id = azurerm_policy_definition.network_manager_spoke_vnets_policy_definition.id
  management_group_id  = azurerm_management_group.management_group_root.id

  display_name = "Azure Virtual Network Manager spoke VNets (${local.suffix})"
  description  = "This policy assignment ensures spoke VNets are added to their corresponding Network Manager network group"
  enforce      = true
  metadata = jsonencode({
    category = "Azure Virtual Network Manager"
    version  = "1.0.0"
  })
  not_scopes = []
  
  timeouts {
    create = "30m"
    read   = "15m"
    update = "25m"
    delete = "20m"
  }
  
  depends_on = [
    time_sleep.sleep_before_policy_assignments
  ]
}
