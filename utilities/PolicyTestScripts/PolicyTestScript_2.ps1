# Define the payload for compliant test
$payload = @{
    location = "eastus"
    kind = "StorageV2"
    sku = @{
        name = "Standard_LRS"
    }
    tags = @{
        Environment = "Production"
    }
} | ConvertTo-Json -Depth 10

# Invoke the REST method to create a compliant storage account
Invoke-AzRestMethod -Uri "https://management.azure.com/subscriptions/be25820a-df86-4794-9e95-6a45cd5c0941/resourceGroups/kneast-rg-eastus/providers/Microsoft.Storage/storageAccounts/compliantstorageaccount?api-version=2022-09-01" -Payload $payload -Method PUT
