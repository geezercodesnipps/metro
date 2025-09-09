#Requires -Version 5.1

<#
.SYNOPSIS
    Finds empty Azure subscriptions for geo region mapping operations.

.DESCRIPTION
    This script discovers empty Azure subscriptions that can be used for new geo regions
    or individual regions. It's designed to work with Azure DevOps pipelines and the
    Manage-GeoRegionMapping.ps1 script.

.PARAMETER Action
    The action that will be performed: 'AddGeo', 'AddRegion'

.PARAMETER MinimumRequired
    Minimum number of empty subscriptions required (default: 1)

.PARAMETER ExcludeSubscriptionIds
    Array of subscription IDs to exclude from the search

.EXAMPLE
    .\Find-EmptySubscriptions.ps1 -Action "AddGeo" -MinimumRequired 1

.EXAMPLE
    .\Find-EmptySubscriptions.ps1 -Action "AddRegion" -MinimumRequired 1 -ExcludeSubscriptionIds @("sub-id-1", "sub-id-2")
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('AddGeo', 'AddRegion')]
    [string]$Action,

    [Parameter(Mandatory = $false)]
    [int]$MinimumRequired = 1,

    [Parameter(Mandatory = $false)]
    [string[]]$ExcludeSubscriptionIds = @(),

    [Parameter(Mandatory = $false)]
    [switch]$OutputForPipeline
)

function Write-LogMessage {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    if ($OutputForPipeline) {
        Write-Host "##[$Level] $Message"
    } else {
        Write-Host "[$timestamp] [$Level] $Message"
    }
}

function Test-SubscriptionEmpty {
    param(
        [string]$SubscriptionId,
        [string]$SubscriptionName
    )
    
    try {
        Write-LogMessage "Checking subscription: $SubscriptionName ($SubscriptionId)"
        
        # Set context to the subscription
        $context = Set-AzContext -SubscriptionId $SubscriptionId -Force -ErrorAction Stop
        if (-not $context) {
            Write-LogMessage "Failed to set context for subscription $SubscriptionId" -Level "WARNING"
            return $false
        }
        
        # Check for resource groups
        $resourceGroups = Get-AzResourceGroup -ErrorAction SilentlyContinue
        $resourceGroupCount = if ($resourceGroups) { $resourceGroups.Count } else { 0 }
        
        # Check for resources directly (some resources might not be in resource groups)
        $resources = Get-AzResource -ErrorAction SilentlyContinue
        $resourceCount = if ($resources) { $resources.Count } else { 0 }
        
        Write-LogMessage "  Resource Groups: $resourceGroupCount, Resources: $resourceCount"
        
        # Consider subscription empty if it has no resources
        $isEmpty = $resourceCount -eq 0
        
        if ($isEmpty) {
            Write-LogMessage "  ✅ Subscription is empty" -Level "INFO"
        } else {
            Write-LogMessage "  ❌ Subscription has resources" -Level "INFO"
        }
        
        return $isEmpty
    } catch {
        Write-LogMessage "Error checking subscription $SubscriptionName : $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Find-EmptySubscriptions {
    Write-LogMessage "🔍 Finding empty subscriptions in tenant..."
    
    try {
        # Get all enabled subscriptions in the tenant
        $allSubscriptions = Get-AzSubscription | Where-Object { $_.State -eq "Enabled" }
        Write-LogMessage "Found $($allSubscriptions.Count) enabled subscriptions in tenant"
        
        if ($allSubscriptions.Count -eq 0) {
            throw "No enabled subscriptions found in tenant"
        }
        
        # Filter out excluded subscriptions
        if ($ExcludeSubscriptionIds.Count -gt 0) {
            $filteredSubscriptions = $allSubscriptions | Where-Object { $_.Id -notin $ExcludeSubscriptionIds }
            Write-LogMessage "Excluded $($allSubscriptions.Count - $filteredSubscriptions.Count) subscriptions from search"
            $allSubscriptions = $filteredSubscriptions
        }
        
        $emptySubscriptions = @()
        
        foreach ($subscription in $allSubscriptions) {
            if (Test-SubscriptionEmpty -SubscriptionId $subscription.Id -SubscriptionName $subscription.Name) {
                $emptySubscriptions += @{
                    Id = $subscription.Id
                    Name = $subscription.Name
                    TenantId = $subscription.TenantId
                }
            }
        }
        
        Write-LogMessage "📊 Found $($emptySubscriptions.Count) empty subscriptions"
        
        return $emptySubscriptions
    } catch {
        Write-LogMessage "Error finding empty subscriptions: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function Select-SubscriptionsForAction {
    param(
        [array]$EmptySubscriptions,
        [string]$Action
    )
    
    if ($EmptySubscriptions.Count -lt $MinimumRequired) {
        throw "Not enough empty subscriptions found. Required: $MinimumRequired, Found: $($EmptySubscriptions.Count)"
    }
    
    $selectedSubscriptions = @{}
    
    switch ($Action) {
        'AddGeo' {
            $selectedSubscriptions['GeoPlatform'] = $EmptySubscriptions[0]
            Write-LogMessage "Selected geo platform subscription: $($EmptySubscriptions[0].Name) ($($EmptySubscriptions[0].Id))"
        }
        'AddRegion' {
            $selectedSubscriptions['Region'] = $EmptySubscriptions[0]
            Write-LogMessage "Selected region subscription: $($EmptySubscriptions[0].Name) ($($EmptySubscriptions[0].Id))"
        }
    }
    
    return $selectedSubscriptions
}

function Output-Results {
    param(
        [hashtable]$SelectedSubscriptions,
        [array]$AllEmptySubscriptions
    )
    
    if ($OutputForPipeline) {
        # Output for Azure DevOps pipeline variables
        foreach ($key in $SelectedSubscriptions.Keys) {
            $subscription = $SelectedSubscriptions[$key]
            $variableName = "selected${key}SubscriptionId"
            Write-Host "##vso[task.setvariable variable=$variableName;isOutput=true]$($subscription.Id)"
            Write-LogMessage "Set pipeline variable: $variableName = $($subscription.Id)"
        }
        
        # Output summary
        Write-Host "##vso[task.setvariable variable=totalEmptySubscriptions;isOutput=true]$($AllEmptySubscriptions.Count)"
    } else {
        # Output for local execution
        Write-LogMessage "=== Selected Subscriptions ==="
        foreach ($key in $SelectedSubscriptions.Keys) {
            $subscription = $SelectedSubscriptions[$key]
            Write-LogMessage "$key : $($subscription.Name) ($($subscription.Id))"
        }
        
        Write-LogMessage "=== All Empty Subscriptions ==="
        for ($i = 0; $i -lt $AllEmptySubscriptions.Count; $i++) {
            $sub = $AllEmptySubscriptions[$i]
            Write-LogMessage "[$i] $($sub.Name) ($($sub.Id))"
        }
    }
}

# Main execution
try {
    Write-LogMessage "Starting empty subscription discovery"
    Write-LogMessage "Action: $Action, Minimum Required: $MinimumRequired"
    
    # Ensure we're connected to Azure
    $context = Get-AzContext
    if (-not $context) {
        throw "Not connected to Azure. Please run Connect-AzAccount first."
    }
    
    Write-LogMessage "Connected to Azure as: $($context.Account.Id)"
    Write-LogMessage "Current tenant: $($context.Tenant.Id)"
    
    # Find empty subscriptions
    $emptySubscriptions = Find-EmptySubscriptions
    
    if ($emptySubscriptions.Count -eq 0) {
        throw "No empty subscriptions found in tenant"
    }
    
    # Select subscriptions based on action
    $selectedSubscriptions = Select-SubscriptionsForAction -EmptySubscriptions $emptySubscriptions -Action $Action
    
    # Output results
    Output-Results -SelectedSubscriptions $selectedSubscriptions -AllEmptySubscriptions $emptySubscriptions
    
    Write-LogMessage "✅ Empty subscription discovery completed successfully"
} catch {
    Write-LogMessage "❌ Error: $($_.Exception.Message)" -Level "ERROR"
    if ($_.Exception.StackTrace) {
        Write-LogMessage "Stack Trace: $($_.Exception.StackTrace)" -Level "ERROR"
    }
    exit 1
}
