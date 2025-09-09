# Wait for management group permissions to propagate before policy assignments
resource "time_sleep" "wait_for_management_group_permissions" {
  create_duration = "60s"
  depends_on = [
    var.artifacts_management_group_root_setup_completed
  ]
}

resource "azurerm_management_group_policy_assignment" "management_group_policy_assignment_allowed_regions_resourcegroups" {
  name                = "Allowed-Regions-RG"
  management_group_id = var.management_group_landing_zones_id
  location            = var.location

  display_name = "Allowed Regions Resource Groups"
  description  = "This policy assignment specifies the allowed Azure Regions for resource groups."
  enforce      = true
  metadata = jsonencode({
    version  = "1.0.0",
    category = "General"
  })
  parameters = jsonencode({
    listOfAllowedLocations = {
      value = var.geo_region_names
    }
  })
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/e765b5de-1225-4ba3-bd56-1ac6695af988"
  not_scopes           = []

  non_compliance_message {
    content = "Please deploy the Resource Group into an approved Azure Region. The selected region is not approved."
  }

  depends_on = [
    time_sleep.wait_for_management_group_permissions
  ]
}

resource "azurerm_management_group_policy_assignment" "management_group_policy_assignment_allowed_regions_resources" {
  name                = "Allowed-Regions-Resource"
  management_group_id = var.management_group_landing_zones_id
  location            = var.location

  display_name = "Allowed Regions Resources"
  description  = "This policy assignment specifies the allowed Azure Regions for resources."
  enforce      = true
  metadata = jsonencode({
    version  = "1.0.0",
    category = "General"
  })
  parameters = jsonencode({
    listOfAllowedLocations = {
      value = var.geo_region_names
    }
    effect = {
      value = "Deny"
    }
  })
  policy_definition_id = "${var.management_group_root_id}/providers/Microsoft.Authorization/policyDefinitions/Deny-Locations-Resources"
  not_scopes           = []

  non_compliance_message {
    content = "Please deploy the Resource into an approved Azure Region. The selected region is not approved."
  }

  depends_on = [
    var.artifacts_management_group_root_setup_completed,
    time_sleep.wait_for_management_group_permissions
  ]
}

resource "azurerm_management_group_policy_assignment" "management_group_policy_assignment_allowed_azure_services" {
  name                = "Allowed-Azure-Services"
  management_group_id = var.management_group_landing_zones_id
  location            = var.location

  display_name = "Allowed Azure Services"
  description  = "This policy assignment specifies the allowed Azure Services for Azure Service Enablement."
  enforce      = true
  metadata = jsonencode({
    version  = "1.0.0",
    category = "General"
  })
  parameters = jsonencode({
    listOfResourceTypesAllowed = {
      value = local.allowed_resource_types
    }
  })
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/a08ec900-254a-4555-9bf5-e42af04b5c5c"
  not_scopes           = []

  non_compliance_message {
    content = "Please deploy an allowed Azure Service. This resource type is denied."
  }

  depends_on = [
    time_sleep.wait_for_management_group_permissions
  ]
}

resource "azurerm_management_group_policy_assignment" "management_group_policy_assignment_denied_azure_services" {
  count = length(var.denied_resource_types) > 0 ? 1 : 0
  
  name                = "Denied-Azure-Services"
  management_group_id = var.management_group_landing_zones_id
  location            = var.location

  display_name = "Denied Azure Services"
  description  = "This policy assignment specifies the denied Azure Services for Azure Service Enablement."
  enforce      = true
  metadata = jsonencode({
    version  = "2.0.0",
    category = "General"
  })
  parameters = jsonencode({
    listOfResourceTypesNotAllowed = {
      value = var.denied_resource_types
    }
    effect = {
      value = "Deny"
    }
  })
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/6c112d4e-5bc7-47ae-a041-ea2d9dccd749"
  not_scopes           = []

  non_compliance_message {
    content = "Please deploy an allowed Azure Service. This resource type is denied."
  }

  depends_on = [
    time_sleep.wait_for_management_group_permissions
  ]
}

resource "azurerm_management_group_policy_assignment" "management_group_policy_assignment_geo_key_vault" {
  name                = "Compliant-Key-Vault"
  management_group_id = var.management_group_landing_zones_id
  location            = var.location
  identity {
    type = "UserAssigned"
    identity_ids = [
      azapi_resource.user_assigned_identity.id
    ]
  }

  display_name = "Enforce secure-by-default Key Vault for regulated industries"
  description  = "This policy initiative is a group of policies that ensures Key Vault is compliant per regulated Landing Zones"
  enforce      = true
  metadata = jsonencode({
    version  = "1.0.0",
    category = "Key Vault"
  })
  parameters = jsonencode({
    keyVaultDiagnostics = {
      value = "DeployIfNotExists"
    }
    keyVaultLogAnalyticsWorkspaceId = {
      value = azapi_resource.log_analytics_workspace.id
    }
    hsmDiagnostics = {
      value = "DeployIfNotExists"
    }
    hsmLogAnalyticsWorkspaceId = {
      value = azapi_resource.log_analytics_workspace.id
    }
  })
  policy_definition_id = "${var.management_group_root_id}/providers/Microsoft.Authorization/policySetDefinitions/Compliant-Key-Vault"
  not_scopes           = []

  non_compliance_message {
    content = "Please provide a valid Key Vault resource definition."
  }

  depends_on = [
    var.artifacts_management_group_root_setup_completed,
    time_sleep.wait_for_management_group_permissions
  ]
}

resource "azurerm_management_group_policy_assignment" "management_group_policy_assignment_geo_log_analytics" {
  name                = "Compliant-Logging-${var.geo_name}"
  management_group_id = var.management_group_platform_id
  location            = var.location
  identity {
    type = "UserAssigned"
    identity_ids = [
      azapi_resource.user_assigned_identity.id
    ]
  }

  display_name = "Enforce secure-by-default logging for regulated industries"
  description  = "This policy initiative is a group of policies that ensures logging is compliant per regulated Landing Zones."
  enforce      = true
  parameters = jsonencode({
    logAnalytics = {
      value = azapi_resource.log_analytics_workspace.id
    }
    resourceLocationList = {
      value = ["var.geo_name"]
    }
  })
  policy_definition_id = "/providers/Microsoft.Authorization/policySetDefinitions/0884adba-2312-4468-abeb-5422caed1038"
  not_scopes           = []

  non_compliance_message {
    content = "Diagnostic settings are not reporting to the correct Log Analytics workspace."
  }

  depends_on = [
    var.artifacts_management_group_root_setup_completed,
    time_sleep.wait_for_management_group_permissions
  ]
}

resource "azurerm_management_group_policy_assignment" "management_group_policy_assignment_geo_network" {
  name                = "Compliant-Network"
  management_group_id = var.management_group_landing_zones_id
  location            = var.location
  identity {
    type = "UserAssigned"
    identity_ids = [
      azapi_resource.user_assigned_identity.id
    ]
  }

  display_name = "Enforce secure-by-default Network and Networking services for regulated industries"
  description  = "This policy initiative is a group of policies that ensures Network and Networking services are compliant per regulated Landing Zones."
  enforce      = true
  metadata = jsonencode({
    version  = "1.0.0",
    category = "Network"
  })
  parameters = jsonencode({
    subnetUdr = {
      value = "Deny"
    }
    subnetNsg = {
      value = "Deny"
    }
    denyInboundInternet = {
      value = "Deny"
    }
    appGwWaf = {
      value = "Deny"
    }
    vnetModifyDdos = {
      value = var.network_ddos_protection_plan_id == "" ? "Disabled" : "Modify"
    }
    ddosPlanResourceId = {
      value = var.network_ddos_protection_plan_id
    }
    nsgDiagnostics = {
      value = "DeployIfNotExists"
    }
    nsgLogAnalyticsWorkspaceId = {
      value = azapi_resource.log_analytics_workspace.id
    }
    wafMode = {
      value = "Deny"
    }
    wafModeRequirement = {
      value = "Prevention"
    }
    wafFwRules = {
      value = "Deny"
    }
    wafModeAppGw = {
      value = "Deny"
    }
    wafModeAppGwRequirement = {
      value = "Prevention"
    }
    lbDiagnostics = {
      value = "DeployIfNotExists"
    }
    lbDiagnosticsLogAnalyticsWorkspaceId = {
      value = azapi_resource.log_analytics_workspace.id
    }
    fdDiagnostics = {
      value = "DeployIfNotExists"
    }
    fdDiagnosticsLogAnalyticsWorkspaceId = {
      value = azapi_resource.log_analytics_workspace.id
    }
    tmDiagnostics = {
      value = "DeployIfNotExists"
    }
    tmDiagnosticsLogAnalyticsWorkspaceId = {
      value = azapi_resource.log_analytics_workspace.id
    }
    vnetDiagnostics = {
      value = "DeployIfNotExists"
    }
    vnetDiagnosticsLogAnalyticsWorkspaceId = {
      value = azapi_resource.log_analytics_workspace.id
    }
    denyRdpFromInternet = {
      value = "Deny"
    }
    denySshFromInternet = {
      value = "Deny"
    }
    erDiagnostics = {
      value = "DeployIfNotExists"
    }
    erDiagnosticsLogAnalyticsWorkspaceId = {
      value = azapi_resource.log_analytics_workspace.id
    }
    bastionDiagnostics = {
      value = "DeployIfNotExists"
    }
    bastionLogAnalyticsWorkspaceId = {
      value = azapi_resource.log_analytics_workspace.id
    }
    bastionLogCategories = {
      value = "allLogs"
    }
    fdCdnDiagnostics = {
      value = "DeployIfNotExists"
    }
    fdCdnLogAnalyticsWorkpaceId = {
      value = azapi_resource.log_analytics_workspace.id
    }
    fdCdnLogCategories = {
      value = "allLogs"
    }
    pipDiagnostics = {
      value = "DeployIfNotExists"
    }
    pipLogAnalyticsWorkspaceId = {
      value = azapi_resource.log_analytics_workspace.id
    }
    pipLogCategories = {
      value = "allLogs"
    }
    gwDiagnostics = {
      value = "DeployIfNotExists"
    }
    gwLogAnalyticsWorkspaceId = {
      value = azapi_resource.log_analytics_workspace.id
    }
    gwLogCategories = {
      value = "allLogs"
    }
    p2sDiagnostics = {
      value = "DeployIfNotExists"
    }
    p2sLogAnalyticsWorkspaceId = {
      value = azapi_resource.log_analytics_workspace.id
    }
    p2sLogCategories = {
      value = "allLogs"
    }
    afwEnableTlsForAllAppRules = {
      value = "Deny"
    }
    afwEnableTlsInspection = {
      value = "Deny"
    }
    afwEmptyIDPSBypassList = {
      value = "Deny"
    }
    afwEnableAllIDPSSignatureRules = {
      value = "Deny"
    }
    afwEnableIDPS = {
      value = "Deny"
    }
    wafAfdEnabled = {
      value = "Deny"
    }
    vpnAzureAD = {
      value = "Deny"
    }
    appGwDiagnostics = {
      value = "DeployIfNotExists"
    }
    appGwLogAnalyticsWorkspaceId = {
      value = azapi_resource.log_analytics_workspace.id
    }
    modifyUdr = {
      value = "Disabled"
    }
    modifyUdrNextHopIpAddress = {
      value = ""
    }
    modifyUdrNextHopType = {
      value = "None"
    }
    modifyUdrAddressPrefix = {
      value = "0.0.0.0/0"
    }
    modifyNsg = {
      value = "Disabled"
    }
    modifyNsgRuleName = {
      value = "DenyAnyInternetOutbound"
    }
    modifyNsgRulePriority = {
      value = 1000
    }
    modifyNsgRuleDirection = {
      value = "Outbound"
    }
    modifyNsgRuleAccess = {
      value = "Deny"
    }
    modifyNsgRuleProtocol = {
      value = "*"
    }
    modifyNsgRuleSourceAddressPrefix = {
      value = "*"
    }
    modifyNsgRuleSourcePortRange = {
      value = "*"
    }
    modifyNsgRuleDestinationAddressPrefix = {
      value = "Internet"
    }
    modifyNsgRuleDestinationPortRange = {
      value = "*"
    }
    modifyNsgRuleDescription = {
      value = "Deny any outbound traffic to the Internet"
    }
    fwDiagnostics = {
      value = "DeployIfNotExists"
    }
    fwLogAnalyticsWorkspaceId = {
      value = azapi_resource.log_analytics_workspace.id
    }
    denyActionVnetPlatform = {
      value = "denyAction"
    }
    spokeVnetPrefix = {
      value = "${var.spoke_prefix}" # We could consider adding "-${lower(var.suffix)}"
    }
    denyActionVnetPeeringAvnm = {
      value = "denyAction"
    }
    vnetPeeringPrefix = {
      value = "ANM_"
    }
  })
  policy_definition_id = "${var.management_group_root_id}/providers/Microsoft.Authorization/policySetDefinitions/Compliant-Network"
  not_scopes           = []

  non_compliance_message {
    content = "Please provide a valid Network resource definition."
  }

  depends_on = [
    var.artifacts_management_group_root_setup_completed,
    time_sleep.wait_for_management_group_permissions
  ]
}

# TODO: Assign GEO Initiatives to the respective scopes
