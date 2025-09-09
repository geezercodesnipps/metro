resource "random_id" "unique_suffix" {
  byte_length = 4
}

resource "azapi_resource" "storage_account" {
  type      = "Microsoft.Storage/storageAccounts@2023-05-01"
  parent_id = azurerm_resource_group.resource_group_logs.id
  name      = substr(replace("stg${local.suffix}${random_id.unique_suffix.hex}", "-", ""), 0, 24)
  location  = var.location
  tags      = var.tags

  body = {
    kind = "StorageV2"
    sku = {
      name = "Standard_LRS"
    }
    properties = {
      accessTier                  = "Hot"
      allowBlobPublicAccess       = false
      allowCrossTenantReplication = false
      allowedCopyScope            = "AAD"
      allowSharedKeyAccess        = false

      defaultToOAuthAuthentication = true
      encryption = {
        keySource = "Microsoft.Storage"
        services = {
          queue = {
            keyType = "Account"
          }
          table = {
            keyType = "Account"
          }
          file = {
            keyType = "Account"
          }
          blob = {
            keyType = "Account"
          }
        }
      }
      isHnsEnabled       = false
      isLocalUserEnabled = false
      isNfsV3Enabled     = false
      isSftpEnabled      = false
      minimumTlsVersion  = "TLS1_2"
      networkAcls = {
        defaultAction       = "Deny"
        bypass              = "AzureServices"
        ipRules             = []
        resourceAccessRules = []
        virtualNetworkRules = []
      }
      publicNetworkAccess = "Enabled"
      sasPolicy = {
        expirationAction    = "Log"
        sasExpirationPeriod = "1.00:00:00"

      }
      supportsHttpsTrafficOnly = true
    }
  }

  response_export_values    = ["*"]
  schema_validation_enabled = true
  locks                     = []
  ignore_casing             = false
  ignore_missing_property   = false
}
