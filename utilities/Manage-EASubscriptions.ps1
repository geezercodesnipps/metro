#Requires -Version 5.1
#Requires -Modules Az.Accounts, Az.Billing, Az.Resources, Az.ManagementGroups

<#
.SYNOPSIS
    Manages Azure subscription creation using Enterprise Agreement (EA) billing with safeguards.

.DESCRIPTION
    This script creates Azure subscriptions using EA billing details while ensuring subscription
    count limits are respected. It includes built-in safeguards to prevent creating more 
    subscriptions than specified and validates EA account access before proceeding.
    
    Subscriptions are created under the tenant root with sequential naming (Subscription 1, 2, 3, etc.).

.PARAMETER EABillingAccountName
    The name of the EA billing account to use for subscription creation.

.PARAMETER EAEnrollmentAccountName
    The name of the EA enrollment account to use for subscription creation.

.PARAMETER MaxSubscriptions
    Maximum number of subscriptions that should exist under the tenant root.

.PARAMETER DryRun
    If specified, performs validation and planning only without creating subscriptions.

.PARAMETER Force
    If specified, bypasses subscription count limits and creates subscriptions anyway.

.EXAMPLE
    .\Manage-EASubscriptions.ps1 -EABillingAccountName "12345678" -EAEnrollmentAccountName "87654321" -MaxSubscriptions 5 -DryRun

.EXAMPLE
    .\Manage-EASubscriptions.ps1 -EABillingAccountName "12345678" -EAEnrollmentAccountName "87654321" -MaxSubscriptions 3 -Force

.NOTES
    Author: Azure DevOps Pipeline Template
    Version: 1.0
    Requires: Az PowerShell modules and appropriate EA permissions
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [string]$EABillingAccountName,

    [Parameter(Mandatory = $true)]
    [string]$EAEnrollmentAccountName,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 50)]
    [int]$MaxSubscriptions = 1,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# Global variables
$script:LogLevel = 'INFO'
$script:ErrorCount = 0

function Write-LogMessage {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'WARNING', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO'
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        'INFO' { 'White' }
        'WARNING' { 'Yellow' }
        'ERROR' { 'Red'; $script:ErrorCount++ }
        'SUCCESS' { 'Green' }
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-AzureConnection {
    Write-LogMessage "🔍 Checking Azure connection..." -Level 'INFO'
    
    try {
        $context = Get-AzContext -ErrorAction Stop
        if (-not $context) {
            throw "No Azure context found"
        }
        
        Write-LogMessage "✅ Connected to Azure as: $($context.Account.Id)" -Level 'SUCCESS'
        Write-LogMessage "   Tenant: $($context.Tenant.Id)" -Level 'INFO'
        Write-LogMessage "   Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))" -Level 'INFO'
        return $true
    } catch {
        Write-LogMessage "❌ Not connected to Azure. Please run Connect-AzAccount first." -Level 'ERROR'
        return $false
    }
}

function Test-EABillingAccess {
    param(
        [string]$BillingAccountName,
        [string]$EnrollmentAccountName
    )
    
    Write-LogMessage "🔍 Validating EA billing account access..." -Level 'INFO'
    
    try {
        # Check billing account access
        $billingAccount = Get-AzBillingAccount -Name $BillingAccountName -ErrorAction SilentlyContinue
        
        if (-not $billingAccount) {
            Write-LogMessage "❌ EA Billing Account '$BillingAccountName' not found or not accessible" -Level 'ERROR'
            Write-LogMessage "   Please verify:" -Level 'ERROR'
            Write-LogMessage "   • EA billing account name is correct" -Level 'ERROR'
            Write-LogMessage "   • Account has EA account reader permissions" -Level 'ERROR'
            Write-LogMessage "   • EA agreement is active" -Level 'ERROR'
            return $false
        }
        
        Write-LogMessage "✅ EA Billing Account found: $($billingAccount.DisplayName)" -Level 'SUCCESS'
        Write-LogMessage "   Account Type: $($billingAccount.AccountType)" -Level 'INFO'
        Write-LogMessage "   Agreement Type: $($billingAccount.AgreementType)" -Level 'INFO'
        
        # Check enrollment account
        $enrollmentAccount = Get-AzEnrollmentAccount -ObjectId $EnrollmentAccountName -ErrorAction SilentlyContinue
        
        if (-not $enrollmentAccount) {
            Write-LogMessage "❌ EA Enrollment Account '$EnrollmentAccountName' not found" -Level 'ERROR'
            Write-LogMessage "   Available enrollment accounts:" -Level 'INFO'
            $availableAccounts = Get-AzEnrollmentAccount -ErrorAction SilentlyContinue
            if ($availableAccounts) {
                $availableAccounts | ForEach-Object { 
                    Write-LogMessage "   • $($_.PrincipalName) ($($_.ObjectId))" -Level 'INFO'
                }
            } else {
                Write-LogMessage "   No enrollment accounts found or accessible" -Level 'WARNING'
            }
            return $false
        }
        
        Write-LogMessage "✅ EA Enrollment Account found: $($enrollmentAccount.PrincipalName)" -Level 'SUCCESS'
        return $true
        
    } catch {
        Write-LogMessage "❌ Error validating EA billing access: $($_.Exception.Message)" -Level 'ERROR'
        return $false
    }
}

function Get-TenantRootSubscriptions {
    Write-LogMessage "🔍 Checking subscriptions under tenant root..." -Level 'INFO'
    
    try {
        # Get all subscriptions in the tenant
        $allSubscriptions = Get-AzSubscription -ErrorAction Stop
        
        Write-LogMessage "📊 Total subscriptions in tenant: $($allSubscriptions.Count)" -Level 'INFO'
        
        # Filter for subscriptions that follow our naming pattern (Subscription X)
        $numberedSubscriptions = $allSubscriptions | Where-Object { $_.Name -match '^Subscription \d+$' }
        
        if ($numberedSubscriptions.Count -gt 0) {
            Write-LogMessage "   Found numbered subscriptions:" -Level 'INFO'
            $numberedSubscriptions | Sort-Object Name | ForEach-Object {
                Write-LogMessage "   • $($_.Name) ($($_.Id))" -Level 'INFO'
            }
            
            # Find highest number
            $highestNumber = ($numberedSubscriptions | ForEach-Object {
                if ($_.Name -match '^Subscription (\d+)$') {
                    [int]$matches[1]
                }
            } | Measure-Object -Maximum).Maximum
            
            Write-LogMessage "   Highest numbered subscription: Subscription $highestNumber" -Level 'INFO'
        } else {
            Write-LogMessage "   No numbered subscriptions found" -Level 'INFO'
            $highestNumber = 0
        }
        
        return @{
            AllSubscriptions = $allSubscriptions
            NumberedSubscriptions = $numberedSubscriptions
            Count = $numberedSubscriptions.Count
            HighestNumber = $highestNumber
        }
        
    } catch {
        Write-LogMessage "❌ Error getting tenant subscriptions: $($_.Exception.Message)" -Level 'ERROR'
        return $null
    }
}

function Test-SubscriptionCountLimits {
    param(
        [int]$CurrentCount,
        [int]$MaxAllowed,
        [bool]$ForceCreate
    )
    
    Write-LogMessage "🔍 Checking subscription count limits..." -Level 'INFO'
    Write-LogMessage "   Current numbered subscriptions: $CurrentCount" -Level 'INFO'
    Write-LogMessage "   Maximum allowed: $MaxAllowed" -Level 'INFO'
    Write-LogMessage "   Force create: $ForceCreate" -Level 'INFO'
    
    if ($CurrentCount -ge $MaxAllowed -and -not $ForceCreate) {
        Write-LogMessage "❌ Maximum subscription count ($MaxAllowed) reached or exceeded" -Level 'ERROR'
        Write-LogMessage "   Current numbered subscriptions: $CurrentCount" -Level 'ERROR'
        Write-LogMessage "   Use -Force to override this limit" -Level 'WARNING'
        return $false
    } elseif ($CurrentCount -ge $MaxAllowed -and $ForceCreate) {
        Write-LogMessage "⚠️ Force create enabled - proceeding despite reaching maximum count" -Level 'WARNING'
        return $true
    } else {
        $subscriptionsToCreate = $MaxAllowed - $CurrentCount
        Write-LogMessage "✅ Can create $subscriptionsToCreate subscription(s)" -Level 'SUCCESS'
        return $true
    }
}

function New-EASubscription {
    param(
        [string]$BillingAccountName,
        [string]$EnrollmentAccountName,
        [string]$SubscriptionName
    )
    
    Write-LogMessage "🚀 Creating EA subscription: $SubscriptionName" -Level 'INFO'
    
    if ($DryRun) {
        Write-LogMessage "📋 DRY RUN: Would create subscription with parameters:" -Level 'INFO'
        Write-LogMessage "   Name: $SubscriptionName" -Level 'INFO'
        Write-LogMessage "   Target: Tenant Root" -Level 'INFO'
        return @{
            Success = $true
            SubscriptionId = "00000000-0000-0000-0000-000000000000"
            Message = "Dry run - no subscription created"
        }
    }
    
    try {
        # Get billing scope
        $billingScope = Get-AzBillingAccount -Name $BillingAccountName | 
                       Get-AzEnrollmentAccount | 
                       Where-Object { $_.ObjectId -eq $EnrollmentAccountName } |
                       Select-Object -First 1
        
        if (-not $billingScope) {
            throw "Could not determine billing scope for enrollment account"
        }
        
        # Generate unique alias
        $alias = "ea-sub-$(Get-Date -Format 'yyyyMMdd-HHmmss')-$(Get-Random -Maximum 9999)"
        
        # Create subscription
        Write-LogMessage "   Creating subscription with alias: $alias" -Level 'INFO'
        
        $newSubscription = New-AzSubscription -Name $SubscriptionName `
                                             -SubscriptionAlias $alias `
                                             -BillingScopeId $billingScope.Id `
                                             -Workload "Production"
        
        if ($newSubscription) {
            Write-LogMessage "✅ Subscription created successfully!" -Level 'SUCCESS'
            Write-LogMessage "   Subscription ID: $($newSubscription.SubscriptionId)" -Level 'INFO'
            Write-LogMessage "   Subscription Name: $($newSubscription.DisplayName)" -Level 'INFO'
            Write-LogMessage "   Location: Tenant Root (no management group assignment)" -Level 'INFO'
            
            return @{
                Success = $true
                SubscriptionId = $newSubscription.SubscriptionId
                SubscriptionName = $newSubscription.DisplayName
                Message = "Subscription created successfully under tenant root"
            }
        } else {
            throw "New-AzSubscription returned null"
        }
        
    } catch {
        Write-LogMessage "❌ Failed to create subscription: $($_.Exception.Message)" -Level 'ERROR'
        return @{
            Success = $false
            SubscriptionId = $null
            Message = $_.Exception.Message
        }
    }
}

function Start-EASubscriptionCreation {
    Write-LogMessage "🚀 Starting EA subscription creation process..." -Level 'INFO'
    
    # Pre-flight checks
    if (-not (Test-AzureConnection)) {
        throw "Azure connection validation failed"
    }
    
    if (-not (Test-EABillingAccess -BillingAccountName $EABillingAccountName -EnrollmentAccountName $EAEnrollmentAccountName)) {
        throw "EA billing access validation failed"
    }
    
    # Get current subscription state
    $subscriptionInfo = Get-TenantRootSubscriptions
    if (-not $subscriptionInfo) {
        throw "Failed to get tenant subscription information"
    }
    
    # Check subscription count limits
    if (-not (Test-SubscriptionCountLimits -CurrentCount $subscriptionInfo.Count -MaxAllowed $MaxSubscriptions -ForceCreate $Force.IsPresent)) {
        throw "Subscription count limit check failed"
    }
    
    # Calculate how many subscriptions to create
    $subscriptionsToCreate = if ($Force.IsPresent) { 1 } else { $MaxSubscriptions - $subscriptionInfo.Count }
    
    if ($subscriptionsToCreate -le 0) {
        Write-LogMessage "✅ No subscriptions need to be created" -Level 'SUCCESS'
        return
    }
    
    Write-LogMessage "📋 Will create $subscriptionsToCreate subscription(s)" -Level 'INFO'
    
    # Create subscriptions with sequential naming
    $results = @()
    $startingNumber = $subscriptionInfo.HighestNumber + 1
    
    for ($i = 0; $i -lt $subscriptionsToCreate; $i++) {
        $subscriptionNumber = $startingNumber + $i
        $subscriptionName = "Subscription $subscriptionNumber"
        
        Write-LogMessage "Creating subscription $($i + 1) of $subscriptionsToCreate..." -Level 'INFO'
        
        $result = New-EASubscription -BillingAccountName $EABillingAccountName `
                                     -EnrollmentAccountName $EAEnrollmentAccountName `
                                     -SubscriptionName $subscriptionName
        
        $results += $result
        
        if ($result.Success) {
            Write-LogMessage "✅ Successfully created: $subscriptionName" -Level 'SUCCESS'
        } else {
            Write-LogMessage "❌ Failed to create: $subscriptionName - $($result.Message)" -Level 'ERROR'
        }
        
        # Add delay between creations to avoid throttling
        if ($i -lt ($subscriptionsToCreate - 1)) {
            Write-LogMessage "⏳ Waiting 30 seconds before creating next subscription..." -Level 'INFO'
            Start-Sleep -Seconds 30
        }
    }
    
    # Summary
    $successCount = ($results | Where-Object { $_.Success }).Count
    $failureCount = ($results | Where-Object { -not $_.Success }).Count
    
    Write-LogMessage "##[section]📊 Creation Summary:" -Level 'INFO'
    Write-LogMessage "   Total attempted: $subscriptionsToCreate" -Level 'INFO'
    Write-LogMessage "   Successful: $successCount" -Level 'SUCCESS'
    Write-LogMessage "   Failed: $failureCount" -Level $(if ($failureCount -gt 0) { 'ERROR' } else { 'INFO' })
    
    if ($DryRun) {
        Write-LogMessage "📋 DRY RUN COMPLETED - No actual subscriptions were created" -Level 'INFO'
    }
    
    return $results
}

# Main execution
try {
    Write-LogMessage "Starting EA Subscription Management Script" -Level 'INFO'
    Write-LogMessage "Script Version: 1.0" -Level 'INFO'
    Write-LogMessage "Execution Mode: $(if ($DryRun) { 'DRY RUN' } else { 'LIVE' })" -Level 'INFO'
    
    # Display configuration
    Write-LogMessage "##[section]📋 Configuration:" -Level 'INFO'
    Write-LogMessage "   EA Billing Account: $EABillingAccountName" -Level 'INFO'
    Write-LogMessage "   EA Enrollment Account: $EAEnrollmentAccountName" -Level 'INFO'
    Write-LogMessage "   Target: Tenant Root" -Level 'INFO'
    Write-LogMessage "   Max Subscriptions: $MaxSubscriptions" -Level 'INFO'
    Write-LogMessage "   Naming: Sequential (Subscription 1, 2, 3, etc.)" -Level 'INFO'
    Write-LogMessage "   Force Create: $($Force.IsPresent)" -Level 'INFO'
    
    # Execute main process
    $results = Start-EASubscriptionCreation
    
    Write-LogMessage "✅ EA subscription management completed successfully!" -Level 'SUCCESS'
    Write-LogMessage "Total errors encountered: $script:ErrorCount" -Level $(if ($script:ErrorCount -gt 0) { 'WARNING' } else { 'SUCCESS' })
    
} catch {
    Write-LogMessage "❌ Script execution failed: $($_.Exception.Message)" -Level 'ERROR'
    Write-LogMessage "Stack trace: $($_.ScriptStackTrace)" -Level 'ERROR'
    exit 1
}
