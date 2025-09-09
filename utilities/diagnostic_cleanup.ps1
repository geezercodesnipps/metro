#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Diagnostic Settings Cleanup Script

.DESCRIPTION
    Removes all diagnostic settings that conflict with Terraform deployments
#>

param(
    [string]$SubscriptionId = $null
)

function Write-Log {
    param([string]$Message, [string]$Level = "Info")
    $emoji = switch ($Level) {
        "Info" { "ℹ️" }
        "Warning" { "⚠️" }
        "Error" { "❌" }
        "Success" { "✅" }
    }
    Write-Host "$emoji $Message" -ForegroundColor $(
        switch ($Level) {
            "Info" { "White" }
            "Warning" { "Yellow" }
            "Error" { "Red" }
            "Success" { "Green" }
        }
    )
}

# Function to comprehensively remove all diagnostic settings from a subscription
function Remove-AllDiagnosticSettings {
    param (
        [string]$SubscriptionId
    )
    
    Write-Log "🧹 Comprehensive diagnostic settings cleanup for subscription: $SubscriptionId" -Level "Info"
    
    try {
        Select-AzSubscription -SubscriptionId $SubscriptionId
        
        # Get authentication token for REST API calls
        $context = Get-AzContext
        $token = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.Id, $null, $null, $null, "https://management.azure.com/").AccessToken
        $headers = @{
            'Authorization' = "Bearer $token"
            'Content-Type' = 'application/json'
        }
        
        # Get all resources in the subscription
        $allResources = Get-AzResource -ErrorAction SilentlyContinue
        
        Write-Log "Found $($allResources.Count) resources to check for diagnostic settings..." -Level "Info"
        
        # Resource types that commonly have diagnostic settings
        $resourceTypesThatSupportDiag = @(
            "Microsoft.Network/networkManagers",
            "Microsoft.OperationalInsights/workspaces",
            "Microsoft.Storage/storageAccounts",
            "Microsoft.KeyVault/vaults",
            "Microsoft.Network/applicationGateways",
            "Microsoft.Network/loadBalancers",
            "Microsoft.Network/networkSecurityGroups",
            "Microsoft.Network/publicIPAddresses",
            "Microsoft.Compute/virtualMachines",
            "Microsoft.Web/sites",
            "Microsoft.Sql/servers",
            "Microsoft.Network/virtualNetworks",
            "Microsoft.Network/virtualNetworkGateways"
        )
        
        $cleanedCount = 0
        
        foreach ($resource in $allResources) {
            try {
                if ($resourceTypesThatSupportDiag -contains $resource.ResourceType) {
                    $diagUri = "https://management.azure.com$($resource.ResourceId)/providers/Microsoft.Insights/diagnosticSettings?api-version=2021-05-01-preview"
                    
                    try {
                        $diagResponse = Invoke-RestMethod -Uri $diagUri -Headers $headers -Method Get -ErrorAction SilentlyContinue
                        
                        if ($diagResponse.value -and $diagResponse.value.Count -gt 0) {
                            Write-Log "Processing $($diagResponse.value.Count) diagnostic settings for: $($resource.Name) ($($resource.ResourceType))" -Level "Info"
                            
                            foreach ($diagSetting in $diagResponse.value) {
                                try {
                                    Write-Host "  Removing diagnostic setting: $($diagSetting.name)" -ForegroundColor Cyan
                                    $deleteUri = "https://management.azure.com$($resource.ResourceId)/providers/Microsoft.Insights/diagnosticSettings/$($diagSetting.name)?api-version=2021-05-01-preview"
                                    Invoke-RestMethod -Uri $deleteUri -Headers $headers -Method Delete -ErrorAction Continue
                                    Write-Log "Successfully removed: $($diagSetting.name)" -Level "Success"
                                    $cleanedCount++
                                    Start-Sleep -Seconds 1  # Small delay to avoid rate limiting
                                }
                                catch {
                                    Write-Log "Failed to remove diagnostic setting $($diagSetting.name): $($_.Exception.Message)" -Level "Warning"
                                }
                            }
                        }
                    }
                    catch {
                        # Ignore errors for resources that don't support diagnostic settings
                        if ($_.Exception.Message -notlike "*NotFound*" -and $_.Exception.Message -notlike "*BadRequest*") {
                            Write-Log "Error checking diagnostic settings for $($resource.Name): $($_.Exception.Message)" -Level "Warning"
                        }
                    }
                }
            }
            catch {
                Write-Log "Error processing resource $($resource.Name): $($_.Exception.Message)" -Level "Warning"
            }
        }
        
        # Also remove subscription-level diagnostic settings
        try {
            Write-Log "Checking subscription-level diagnostic settings..." -Level "Info"
            $subDiagUri = "https://management.azure.com/subscriptions/$SubscriptionId/providers/Microsoft.Insights/diagnosticSettings?api-version=2021-05-01-preview"
            $subDiagResponse = Invoke-RestMethod -Uri $subDiagUri -Headers $headers -Method Get -ErrorAction SilentlyContinue
            
            if ($subDiagResponse.value) {
                foreach ($diagSetting in $subDiagResponse.value) {
                    try {
                        Write-Host "  Removing subscription diagnostic setting: $($diagSetting.name)" -ForegroundColor Cyan
                        $deleteUri = "https://management.azure.com/subscriptions/$SubscriptionId/providers/Microsoft.Insights/diagnosticSettings/$($diagSetting.name)?api-version=2021-05-01-preview"
                        Invoke-RestMethod -Uri $deleteUri -Headers $headers -Method Delete -ErrorAction Continue
                        Write-Log "Successfully removed subscription diagnostic setting: $($diagSetting.name)" -Level "Success"
                        $cleanedCount++
                    }
                    catch {
                        Write-Log "Failed to remove subscription diagnostic setting $($diagSetting.name): $($_.Exception.Message)" -Level "Warning"
                    }
                }
            }
        }
        catch {
            Write-Log "Error removing subscription diagnostic settings: $($_.Exception.Message)" -Level "Warning"
        }
        
        Write-Log "Diagnostic settings cleanup completed! Removed $cleanedCount diagnostic settings from subscription: $SubscriptionId" -Level "Success"
    }
    catch {
        Write-Log "Critical error in diagnostic settings cleanup: $($_.Exception.Message)" -Level "Error"
    }
}

# Main execution
Write-Host @"
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║   DIAGNOSTIC SETTINGS CLEANUP FOR TERRAFORM CONFLICTS            ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

$context = Get-AzContext
if (-not $context) {
    Write-Log "Not connected to Azure. Please run Connect-AzAccount first." -Level "Error"
    exit 1
}

Write-Log "Connected as: $($context.Account.Id)" -Level "Success"

# If no subscription ID provided, use all subscriptions from the config
if (-not $SubscriptionId) {
    $subs = @(
        "4f007f2c-5c8d-4a59-8f0c-9d194c1ed152", # Global platform
        "fbbce6e6-ff30-4bca-8895-c1d306b5de7f", # EMEA geo platform  
        "c8e99e94-859c-46af-9907-a20b56753a2e"  # Network subscription
    )
    
    Write-Log "Processing $($subs.Count) subscriptions from configuration..." -Level "Info"
    
    foreach ($sub in $subs) {
        Write-Log "Processing subscription: $sub" -Level "Info"
        Remove-AllDiagnosticSettings -SubscriptionId $sub
        Write-Host "" # Add spacing between subscriptions
    }
}
else {
    Write-Log "Processing single subscription: $SubscriptionId" -Level "Info"
    Remove-AllDiagnosticSettings -SubscriptionId $SubscriptionId
}

Write-Log "Diagnostic cleanup completed successfully!" -Level "Success"
