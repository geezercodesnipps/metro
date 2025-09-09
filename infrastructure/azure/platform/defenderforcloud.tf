resource "azapi_update_resource" "security_center_subscription_pricing_virtual_machines" {
  for_each = toset(local.subscription_ids_all)

  type      = "Microsoft.Security/pricings@2024-01-01"
  parent_id = "/subscriptions/${each.key}"
  name      = "VirtualMachines"

  body = {
    properties = {
      pricingTier = "Standard"
      subPlan     = "P2"
      enforce     = "True"
      extensions = [
        {
          name      = "MdeDesignatedSubscription",
          isEnabled = "False"
        },
        {
          name      = "AgentlessVmScanning",
          isEnabled = "True",
          additionalExtensionProperties = {
            ExclusionTags = "[]"
          }
        },
        {
          name      = "FileIntegrityMonitoring",
          isEnabled = "False",
          # additionalExtensionProperties = {
          #   DefinedWorkspaceId = ""
          # }
        }
      ]
    }
  }

  response_export_values  = []
  locks                   = []
  ignore_casing           = false
  ignore_missing_property = false
}

resource "azapi_update_resource" "security_center_subscription_pricing_sql_servers" {
  for_each = toset(local.subscription_ids_all)

  type      = "Microsoft.Security/pricings@2024-01-01"
  parent_id = "/subscriptions/${each.key}"
  name      = "SqlServers"

  body = {
    properties = {
      pricingTier = "Standard"
      subPlan     = null
      enforce     = "True"
      extensions  = []
    }
  }

  response_export_values  = []
  locks                   = []
  ignore_casing           = false
  ignore_missing_property = false
}

resource "azapi_update_resource" "security_center_subscription_pricing_sql_server_virtual_machines" {
  for_each = toset(local.subscription_ids_all)

  type      = "Microsoft.Security/pricings@2024-01-01"
  parent_id = "/subscriptions/${each.key}"
  name      = "SqlServerVirtualMachines"

  body = {
    properties = {
      pricingTier = "Standard"
      subPlan     = null
      enforce     = "True"
      extensions  = []
    }
  }

  response_export_values  = []
  locks                   = []
  ignore_casing           = false
  ignore_missing_property = false
}

resource "azapi_update_resource" "security_center_subscription_pricing_open_source_relational_dbs" {
  for_each = toset(local.subscription_ids_all)

  type      = "Microsoft.Security/pricings@2024-01-01"
  parent_id = "/subscriptions/${each.key}"
  name      = "OpenSourceRelationalDatabases"

  body = {
    properties = {
      pricingTier = "Standard"
      subPlan     = null
      enforce     = "True"
      extensions  = []
    }
  }

  response_export_values  = []
  locks                   = []
  ignore_casing           = false
  ignore_missing_property = false
}

resource "azapi_update_resource" "security_center_subscription_pricing_cosmos_dbs" {
  for_each = toset(local.subscription_ids_all)

  type      = "Microsoft.Security/pricings@2024-01-01"
  parent_id = "/subscriptions/${each.key}"
  name      = "CosmosDbs"

  body = {
    properties = {
      pricingTier = "Standard"
      subPlan     = null
      enforce     = "True"
      extensions  = []
    }
  }

  response_export_values  = []
  locks                   = []
  ignore_casing           = false
  ignore_missing_property = false
}

resource "azapi_update_resource" "security_center_subscription_pricing_storage_accounts" {
  for_each = toset(local.subscription_ids_all)

  type      = "Microsoft.Security/pricings@2024-01-01"
  parent_id = "/subscriptions/${each.key}"
  name      = "StorageAccounts"

  body = {
    properties = {
      pricingTier = "Standard"
      subPlan     = "DefenderForStorageV2"
      enforce     = "True"
      extensions = [
        {
          name      = "OnUploadMalwareScanning",
          isEnabled = "True",
          additionalExtensionProperties = {
            CapGBPerMonthPerStorageAccount = "5000"
          }
        },
        {
          name      = "SensitiveDataDiscovery",
          isEnabled = "True"
        }
      ]
    }
  }

  response_export_values  = []
  locks                   = []
  ignore_casing           = false
  ignore_missing_property = false
}

resource "azapi_update_resource" "security_center_subscription_pricing_key_vaults" {
  for_each = toset(local.subscription_ids_all)

  type      = "Microsoft.Security/pricings@2024-01-01"
  parent_id = "/subscriptions/${each.key}"
  name      = "KeyVaults"

  body = {
    properties = {
      pricingTier = "Standard"
      subPlan     = "PerKeyVault"
      enforce     = "True"
      extensions  = []
    }
  }

  response_export_values  = []
  locks                   = []
  ignore_casing           = false
  ignore_missing_property = false
}

resource "azapi_update_resource" "security_center_subscription_pricing_arm" {
  for_each = toset(local.subscription_ids_all)

  type      = "Microsoft.Security/pricings@2024-01-01"
  parent_id = "/subscriptions/${each.key}"
  name      = "Arm"

  body = {
    properties = {
      pricingTier = "Standard"
      subPlan     = "PerSubscription"
      enforce     = "True"
      extensions  = []
    }
  }

  response_export_values  = []
  locks                   = []
  ignore_casing           = false
  ignore_missing_property = false
}

resource "azapi_update_resource" "security_center_subscription_pricing_containers" {
  for_each = toset(local.subscription_ids_all)

  type      = "Microsoft.Security/pricings@2024-01-01"
  parent_id = "/subscriptions/${each.key}"
  name      = "Containers"

  body = {
    properties = {
      pricingTier = "Standard"
      subPlan     = null
      enforce     = "True"
      extensions = [
        {
          name      = "ContainerRegistriesVulnerabilityAssessments",
          isEnabled = "True"
        },
        {
          name      = "AgentlessDiscoveryForKubernetes",
          isEnabled = "True"
        }
        # ,
        # {
        #   name      = "ContainerSensor",
        #   isEnabled = "True"
        #   additionalExtensionProperties = {
        #     extensionDetails = "InAdditionToSensorPolicyEnablement"
        #   }
        # }
      ]
    }
  }

  response_export_values  = []
  locks                   = []
  ignore_casing           = false
  ignore_missing_property = false
}

resource "azapi_update_resource" "security_center_subscription_pricing_cloud_posture" {
  for_each = toset(local.subscription_ids_all)

  type      = "Microsoft.Security/pricings@2024-01-01"
  parent_id = "/subscriptions/${each.key}"
  name      = "CloudPosture"

  body = {
    properties = {
      pricingTier = "Standard"
      subPlan     = null
      enforce     = "True"
      extensions = [
        {
          name      = "SensitiveDataDiscovery",
          isEnabled = "True"
        },
        {
          name      = "ContainerRegistriesVulnerabilityAssessments",
          isEnabled = "True"
        },
        {
          name      = "AgentlessDiscoveryForKubernetes",
          isEnabled = "True"
        },
        {
          name      = "AgentlessVmScanning",
          isEnabled = "True"
          additionalExtensionProperties = {
            ExclusionTags = "[]"
          }
        },
        {
          name      = "EntraPermissionsManagement",
          isEnabled = "True"
        },
      ]
    }
  }

  response_export_values  = []
  locks                   = []
  ignore_casing           = false
  ignore_missing_property = false
}

resource "azapi_update_resource" "security_center_subscription_pricing_app_services" {
  for_each = toset(local.subscription_ids_all)

  type      = "Microsoft.Security/pricings@2024-01-01"
  parent_id = "/subscriptions/${each.key}"
  name      = "AppServices"

  body = {
    properties = {
      pricingTier = "Standard"
      subPlan     = null
      enforce     = "True"
      extensions  = []
    }
  }

  response_export_values  = []
  locks                   = []
  ignore_casing           = false
  ignore_missing_property = false
}

resource "azapi_update_resource" "security_center_subscription_pricing_api" {
  for_each = toset(local.subscription_ids_all)

  type      = "Microsoft.Security/pricings@2024-01-01"
  parent_id = "/subscriptions/${each.key}"
  name      = "Api"

  body = {
    properties = {
      pricingTier = "Free"
      subPlan     = null
      enforce     = "True"
      extensions  = []
    }
  }

  response_export_values  = []
  locks                   = []
  ignore_casing           = false
  ignore_missing_property = false
}

# resource "azapi_update_resource" "security_center_automation" {
#   for_each = toset(local.subscription_ids_all)

#   type      = "Microsoft.Security/automations@2023-12-01-preview"
#   parent_id = "/subscriptions/${each.key}"
#   name      = "ExportToWorkspace"

#   body = {
#     properties = {
#       description = "Export Azure Security Center data to Log Analytics workspace via policy"
#       actions = [
#         {
#           actionType          = "Workspace"
#           workspaceResourceId = "" # TODO: Define Export strategy
#         }
#       ]
#       isEnabled = true
#       scopes = [
#         {
#           description = "Scope for subscription ${each.key}"
#           scopePath   = "/subscriptions/${each.key}"
#         }
#       ]
#       sources = [
#         {
#           eventSource = "Alerts"
#           ruleSets = [
#             {
#               rules = [
#                 {
#                   expectedValue = "High"
#                   operator      = "Equals"
#                   propertyJPath = "Severity"
#                   propertyType  = "String"
#                 },
#                 {
#                   expectedValue = "Medium"
#                   operator      = "Equals"
#                   propertyJPath = "Severity"
#                   propertyType  = "String"
#                 }
#               ]
#             }
#           ]
#         },
#         {
#           eventSource = "Assessments"
#           ruleSets    = [] # TODO
#         },
#         {
#           eventSource = "SubAssessments"
#           ruleSets    = [] # TODO
#         },
#         {
#           eventSource = "SecureScores"
#           ruleSets    = [] # TODO
#         },
#         {
#           eventSource = "SecureScoreControls"
#           ruleSets    = [] # TODO
#         },
#         {
#           eventSource = "RegulatoryComplianceAssessment"
#           ruleSets    = [] # TODO
#         },
#         {
#           eventSource = "SecureScoresSnapshot"
#           ruleSets    = [] # TODO
#         },
#         {
#           eventSource = "SecureScoreControlsSnapshot"
#           ruleSets    = [] # TODO
#         },
#         {
#           eventSource = "RegulatoryComplianceAssessmentSnapshot"
#           ruleSets    = [] # TODO
#         }
#       ]
#     }
#   }

#   response_export_values    = []
#   locks                     = []
#   ignore_casing             = false
#   ignore_missing_property   = false
# }
