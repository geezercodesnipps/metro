output "storage_account_id" {
  description = "Specifies the resource ID of a storage account, where the log data should be stored."
  sensitive   = false
  value       = azapi_resource.storage_account.id
}
