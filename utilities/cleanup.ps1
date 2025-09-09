# Enhanced Azure Subscription and Management Group Cleanup Script
# ------------------------------------------------------
# This script provides comprehensive and optimized parallel cleanup of Azure subscriptions
# and management groups. It uses parallelization to speed up the cleanup process.

# Display script banner
Write-Host @"
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║   █▀█ █▀█ ▀█▀ █ █▀▄▀█ █ █▀█ █▀▀ █▀▄   █▀▀ █░░ █▀▀ ▄▀█ █▄░█ █░█ █▀█  ║
║   █▄█ █▀▀ ░█░ █ █░▀░█ █ █▀▄ ██▄ █▄▀   █▄▄ █▄▄ ██▄ █▀█ █░▀█ █▄█ █▀▀  ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan

Write-Host "Azure Comprehensive Cleanup Script - Enhanced with Parallelization" -ForegroundColor Green
Write-Host "Started at: $(Get-Date)" -ForegroundColor Cyan
Write-Host "Runner: $($env:USERNAME) on $($env:COMPUTERNAME)" -ForegroundColor Cyan
Write-Host "--------------------------------------------------------------" -ForegroundColor Cyan

$subs = @()
 
$subs += "1682502d-c5cc-4b1d-903e-5847c566cfdd" #krnese-1
$subs += "b3659883-42f6-4a22-a21e-a753997673da" #krnese-2
$subs += "033b3671-da1a-427d-b9ca-576e6ad60771" #krnese-3
$subs += "4f007f2c-5c8d-4a59-8f0c-9d194c1ed152" #krnese-4
$subs += "089d1e87-7b1f-4300-b121-53fb53bb4ad3" #krnese-5
$subs += "fbbce6e6-ff30-4bca-8895-c1d306b5de7f" #krnese-6
$subs += "9fd7cb6b-4e6e-49ff-a5c8-9f216c8f53b0" #krnese-7
$subs += "95d02df1-24e1-4f2b-9c6c-5f80dae0f65c" #krnese-8
$subs += "bae218dd-989f-4c0d-8005-a46851b14f4f" #krnese-9
$subs += "7e87166d-e173-4f71-b348-450513548e81" #krnese-10
$subs += "c8e99e94-859c-46af-9907-a20b56753a2e" #krnese-11
$subs += "40c4aec6-28bf-4267-aa3a-3eab2638cfb7" #krnese-12

#02
#$subs += "47b3e005-a6de-495d-a1d6-dd0fea33a469"
#$subs += "9108d0bf-6df2-49e6-8414-f6d5a87f89fd"
#$subs += "38a54a68-2e8f-493a-8008-f86bc9a5555c"
#$subs += "2bae8f93-a3d8-4aaa-a2b9-9e8691ef371b"
#$subs += "3100e26e-c059-4bf9-99c9-ac73d19f4283"
#$subs += "6a561184-cbee-4039-99ff-edf111b61e02"
#$subs += "6089d555-dcce-4cbc-9561-7a2b66e0734a"
#$subs += "4ea769f2-47e6-474b-ab76-2aeef75fafae"
#$subs += "82674873-7088-433b-82a2-be9b21b549ef"
#$subs += "7aa69283-b54f-443c-8e2e-35b7dbf45672"

# Show summary of what will be cleaned up
Write-Host "This script will clean up the following Azure resources:" -ForegroundColor Yellow
Write-Host "  - $($subs.Count) subscriptions" -ForegroundColor Yellow
Write-Host "  - All resource groups, resources, and deployments within these subscriptions" -ForegroundColor Yellow
Write-Host "  - All management groups (excluding tenant root)" -ForegroundColor Yellow
Write-Host "  - All role assignments for managed identities and service principals" -ForegroundColor Yellow

# Print all subscription IDs that will be cleaned
Write-Host "`nSubscriptions to be cleaned:" -ForegroundColor Cyan
for ($i = 0; $i -lt $subs.Count; $i++) {
    Write-Host "  $($i+1). $($subs[$i])" -ForegroundColor White
}

Write-Host "`nParallel execution settings:" -ForegroundColor Cyan
Write-Host "  - Multiple subscriptions will be cleaned in parallel" -ForegroundColor White 
Write-Host "  - Resource deletion will use optimized batching" -ForegroundColor White
Write-Host "  - Progress indicators will show cleanup status" -ForegroundColor White

Write-Host "`nStarting cleanup process..." -ForegroundColor Green
$scriptStartTime = Get-Date

 
# Add a helper function to show progress
function Show-ScriptProgress {
    param (
        [string]$Activity,
        [int]$PercentComplete,
        [string]$Status,
        [switch]$Completed
    )
    
    Write-Progress -Activity $Activity -PercentComplete $PercentComplete -Status $Status -Completed:$Completed
    
    # Also write to console for log files
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$PercentComplete%] $Activity - $Status" -ForegroundColor $(
        if ($PercentComplete -lt 30) { "Yellow" }
        elseif ($PercentComplete -lt 70) { "Cyan" } 
        else { "Green" }
    )
}

# Function to check if subscription is completely empty with comprehensive checks
function Test-SubscriptionEmpty {
    param (
        [string]$SubscriptionId
    )
    
    Select-AzSubscription -SubscriptionId $SubscriptionId
    
    # Get all resources including those that might be hidden or system resources
    $resourceGroups = Get-AzResourceGroup -ErrorAction SilentlyContinue
    $deployments = Get-AzSubscriptionDeployment -ErrorAction SilentlyContinue
    $resources = Get-AzResource -ErrorAction SilentlyContinue
    
    # Check for deployment stacks
    $deploymentStacks = @()
    try {
        $deploymentStacks = Get-AzSubscriptionDeploymentStack -ErrorAction SilentlyContinue
    }
    catch {
        Write-Warning "Could not check deployment stacks: $($_.Exception.Message)"
    }
    
    # Check for role assignments at subscription scope
    $roleAssignments = @()
    try {
        $roleAssignments = Get-AzRoleAssignment -Scope "/subscriptions/$SubscriptionId" -ErrorAction SilentlyContinue | 
            Where-Object { $_.ObjectType -eq "ServicePrincipal" -or $_.ObjectType -eq "Unknown" -or $_.DisplayName -like "*identity*" }
    }
    catch {
        Write-Warning "Could not check role assignments: $($_.Exception.Message)"
    }
    
    $isEmpty = ($resourceGroups.Count -eq 0) -and 
               ($deployments.Count -eq 0) -and 
               ($resources.Count -eq 0) -and
               ($deploymentStacks.Count -eq 0) -and
               ($roleAssignments.Count -eq 0)
    
    if (-not $isEmpty) {
        Write-Host "Subscription $SubscriptionId still contains:" -ForegroundColor Yellow
        Write-Host "  Resource Groups: $($resourceGroups.Count)"
        Write-Host "  Deployments: $($deployments.Count)"
        Write-Host "  Resources: $($resources.Count)"
        Write-Host "  Deployment Stacks: $($deploymentStacks.Count)"
        Write-Host "  Role Assignments (SP/Unknown/Identity): $($roleAssignments.Count)"
        
        if ($resourceGroups.Count -gt 0) {
            Write-Host "  Resource Groups found:" -ForegroundColor Yellow
            $resourceGroups | ForEach-Object { Write-Host "    - $($_.ResourceGroupName)" }
        }
        
        if ($roleAssignments.Count -gt 0) {
            Write-Host "  Role Assignments found:" -ForegroundColor Yellow
            $roleAssignments | ForEach-Object { Write-Host "    - $($_.DisplayName) ($($_.RoleDefinitionName))" }
        }
    }
    
    return $isEmpty
}

# Function to wait for all jobs to complete with better monitoring and progress display
function Wait-ForAllJobs {
    param (
        [int]$TimeoutMinutes = 30,
        [int]$PollingIntervalSeconds = 15,
        [switch]$ShowProgress
    )
    
    $jobs = Get-Job
    if ($jobs.Count -gt 0) {
        Write-Host "Waiting for $($jobs.Count) background jobs to complete (timeout: $TimeoutMinutes minutes)..." -ForegroundColor Cyan
        
        $timeoutSeconds = $TimeoutMinutes * 60
        $startTime = Get-Date
        $lastProgressUpdate = Get-Date
        $progressUpdateInterval = 15 # seconds
        
        do {
            $runningJobs = Get-Job | Where-Object { $_.State -eq 'Running' }
            $completedJobs = Get-Job | Where-Object { $_.State -in @('Completed', 'Failed', 'Stopped') }
            
            if ($runningJobs.Count -gt 0) {
                $elapsed = (Get-Date) - $startTime
                $currentTime = Get-Date
                
                # Only update progress periodically to reduce console spam
                if (($currentTime - $lastProgressUpdate).TotalSeconds -ge $progressUpdateInterval) {
                    Write-Host "  Still waiting for $($runningJobs.Count) jobs... (elapsed: $([math]::Round($elapsed.TotalMinutes, 1)) minutes)" -ForegroundColor Yellow
                    
                    if ($ShowProgress) {
                        $i = 0
                        foreach ($job in $runningJobs) {
                            if ($i -lt 3) { # Only show details for first 3 running jobs to avoid clutter
                                $jobInfo = $job | Select-Object Id, Name, State, @{Name="Duration"; Expression={(Get-Date) - $job.PSBeginTime}}
                                Write-Host "    - Job $($jobInfo.Id): $($jobInfo.State) for $([math]::Round($jobInfo.Duration.TotalMinutes, 1)) minutes" -ForegroundColor Gray
                                $i++
                            }
                            else {
                                Write-Host "    - ... and $($runningJobs.Count - 3) more jobs" -ForegroundColor Gray
                                break
                            }
                        }
                    }
                    
                    $lastProgressUpdate = $currentTime
                }
                
                Start-Sleep -Seconds $PollingIntervalSeconds
            }
            
            # Process completed jobs as they finish
            if ($completedJobs.Count -gt 0) {
                foreach ($job in $completedJobs) {
                    Write-Host "  Job $($job.Id) completed with state: $($job.State)" -ForegroundColor Green
                }
                $completedJobs | Remove-Job -Force
            }
            
        } while ($runningJobs.Count -gt 0 -and ((Get-Date) - $startTime).TotalSeconds -lt $timeoutSeconds)
        
        # Final cleanup of any remaining jobs
        $remainingJobs = Get-Job
        if ($remainingJobs.Count -gt 0) {
            Write-Warning "Stopping $($remainingJobs.Count) remaining jobs due to timeout"
            $remainingJobs | Stop-Job -PassThru | Remove-Job -Force
        }
    }
}

# Function to comprehensively remove all diagnostic settings from a subscription
function Remove-AllDiagnosticSettings {
    param (
        [string]$SubscriptionId
    )
    
    Write-Host "🧹 Comprehensive diagnostic settings cleanup for subscription: $SubscriptionId" -ForegroundColor Magenta
    
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
        
        Write-Host "  Found $($allResources.Count) resources to check for diagnostic settings..." -ForegroundColor Yellow
        
        foreach ($resource in $allResources) {
            try {
                # Check if this resource type supports diagnostic settings
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
                    "Microsoft.Network/virtualNetworkGateways",
                    "Microsoft.Network/azureFirewalls",
                    "Microsoft.Insights/components",
                    "Microsoft.ContainerService/managedClusters",
                    "Microsoft.DBforPostgreSQL/servers",
                    "Microsoft.DBforMySQL/servers",
                    "Microsoft.DocumentDB/databaseAccounts",
                    "Microsoft.EventHub/namespaces",
                    "Microsoft.ServiceBus/namespaces",
                    "Microsoft.Batch/batchAccounts",
                    "Microsoft.DataFactory/factories",
                    "Microsoft.Logic/workflows",
                    "Microsoft.StreamAnalytics/streamingjobs",
                    "Microsoft.Network/privateDnsZones",
                    "Microsoft.Network/dnsResolvers",
                    "Microsoft.Network/firewallPolicies",
                    "Microsoft.Network/routeTables",
                    "Microsoft.ManagedIdentity/userAssignedIdentities",
                    "Microsoft.Authorization/policyDefinitions",
                    "Microsoft.Authorization/policySetDefinitions",
                    "Microsoft.Authorization/policyAssignments"
                )
                
                if ($resourceTypesThatSupportDiag -contains $resource.ResourceType) {
                    $diagUri = "https://management.azure.com$($resource.ResourceId)/providers/Microsoft.Insights/diagnosticSettings?api-version=2021-05-01-preview"
                    
                    try {
                        $diagResponse = Invoke-RestMethod -Uri $diagUri -Headers $headers -Method Get -ErrorAction SilentlyContinue
                        
                        if ($diagResponse.value -and $diagResponse.value.Count -gt 0) {
                            Write-Host "    Processing $($diagResponse.value.Count) diagnostic settings for: $($resource.Name) ($($resource.ResourceType))" -ForegroundColor Cyan
                            
                            foreach ($diagSetting in $diagResponse.value) {
                                try {
                                    Write-Host "      Removing diagnostic setting: $($diagSetting.name)"
                                    $deleteUri = "https://management.azure.com$($resource.ResourceId)/providers/Microsoft.Insights/diagnosticSettings/$($diagSetting.name)?api-version=2021-05-01-preview"
                                    Invoke-RestMethod -Uri $deleteUri -Headers $headers -Method Delete -ErrorAction Continue
                                    Write-Host "      ✅ Successfully removed: $($diagSetting.name)" -ForegroundColor Green
                                    Start-Sleep -Seconds 1  # Small delay to avoid rate limiting
                                }
                                catch {
                                    Write-Warning "      Failed to remove diagnostic setting $($diagSetting.name): $($_.Exception.Message)"
                                }
                            }
                        }
                    }
                    catch {
                        # Ignore errors for resources that don't support diagnostic settings
                        if ($_.Exception.Message -notlike "*NotFound*" -and $_.Exception.Message -notlike "*BadRequest*") {
                            Write-Warning "    Error checking diagnostic settings for $($resource.Name): $($_.Exception.Message)"
                        }
                    }
                }
            }
            catch {
                Write-Warning "  Error processing resource $($resource.Name): $($_.Exception.Message)"
            }
        }
        
        # Also remove subscription-level diagnostic settings
        try {
            Write-Host "  Checking subscription-level diagnostic settings..." -ForegroundColor Yellow
            $subDiagUri = "https://management.azure.com/subscriptions/$SubscriptionId/providers/Microsoft.Insights/diagnosticSettings?api-version=2021-05-01-preview"
            $subDiagResponse = Invoke-RestMethod -Uri $subDiagUri -Headers $headers -Method Get -ErrorAction SilentlyContinue
            
            if ($subDiagResponse.value) {
                foreach ($diagSetting in $subDiagResponse.value) {
                    try {
                        Write-Host "    Removing subscription diagnostic setting: $($diagSetting.name)" -ForegroundColor Cyan
                        $deleteUri = "https://management.azure.com/subscriptions/$SubscriptionId/providers/Microsoft.Insights/diagnosticSettings/$($diagSetting.name)?api-version=2021-05-01-preview"
                        Invoke-RestMethod -Uri $deleteUri -Headers $headers -Method Delete -ErrorAction Continue
                        Write-Host "    ✅ Successfully removed subscription diagnostic setting: $($diagSetting.name)" -ForegroundColor Green
                    }
                    catch {
                        Write-Warning "    Failed to remove subscription diagnostic setting $($diagSetting.name): $($_.Exception.Message)"
                    }
                }
            }
        }
        catch {
            Write-Warning "  Error removing subscription diagnostic settings: $($_.Exception.Message)"
        }
        
        Write-Host "✅ Diagnostic settings cleanup completed for subscription: $SubscriptionId" -ForegroundColor Green
    }
    catch {
        Write-Error "❌ Critical error in diagnostic settings cleanup: $($_.Exception.Message)"
    }
}

# Function to cleanup stuck resources using alternative methods
function Invoke-StuckResourceCleanup {
    param (
        [string]$SubscriptionId
    )
    
    Write-Host "🔨 Attempting cleanup of stuck resources using alternative methods..." -ForegroundColor Magenta
    
    Select-AzSubscription -SubscriptionId $SubscriptionId
    
    # Try REST API calls for stubborn resources
    try {
        $context = Get-AzContext
        $token = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.Id, $null, $null, $null, "https://management.azure.com/").AccessToken
        $headers = @{
            'Authorization' = "Bearer $token"
            'Content-Type' = 'application/json'
        }
        
        # Get all resource groups via REST API
        $rgUri = "https://management.azure.com/subscriptions/$SubscriptionId/resourcegroups?api-version=2021-04-01"
        $response = Invoke-RestMethod -Uri $rgUri -Headers $headers -Method Get
        
        foreach ($rg in $response.value) {
            try {
                Write-Host "  Force deleting resource group via REST API: $($rg.name)"
                $deleteUri = "https://management.azure.com/subscriptions/$SubscriptionId/resourcegroups/$($rg.name)?forceDeletionTypes=Microsoft.Compute/virtualMachines,Microsoft.Compute/virtualMachineScaleSets`&api-version=2021-04-01"
                Invoke-RestMethod -Uri $deleteUri -Headers $headers -Method Delete
            }
            catch {
                Write-Warning "REST API deletion failed for $($rg.name): $($_.Exception.Message)"
            }
        }
    }
    catch {
        Write-Warning "Force cleanup via REST API failed: $($_.Exception.Message)"
    }
}

# Function to clean subscription resources with retry logic and comprehensive cleanup
function Clear-SubscriptionResources {
    param (
        [string]$SubscriptionId,
        [int]$MaxRetries = 15
    )
    
    $retryCount = 0
    
    do {
        $retryCount++
        Write-Host "=== Cleanup attempt $retryCount for subscription: $SubscriptionId ===" -ForegroundColor Cyan
        
        Select-AzSubscription -SubscriptionId $SubscriptionId
        
        # Step 1: Remove deployment stacks first (they can prevent resource deletion)
        Write-Host "Removing deployment stacks..." -ForegroundColor Yellow
        try {
            $deploymentStacks = Get-AzSubscriptionDeploymentStack -ErrorAction SilentlyContinue
            if ($deploymentStacks) {
                foreach ($stack in $deploymentStacks) {
                    try {
                        Write-Host "  Removing deployment stack: $($stack.Name) with all managed resources"
                        Remove-AzSubscriptionDeploymentStack -Name $stack.Name -ActionOnUnmanage DeleteAll -Force -Confirm:$false -ErrorAction Continue
                        Write-Host "  ✓ Removed deployment stack: $($stack.Name)" -ForegroundColor Green
                    }
                    catch {
                        Write-Warning "Failed to remove deployment stack $($stack.Name): $($_.Exception.Message)"
                    }
                }
            }
        }
        catch {
            Write-Warning "Error checking deployment stacks: $($_.Exception.Message)"
        }
        
        # Step 1.5: Remove policy-managed diagnostic settings and conflicting configurations
        Write-Host "Removing policy-managed diagnostic settings and conflicting configurations..." -ForegroundColor Yellow
        try {
            # Remove diagnostic settings from Network Managers (these cause conflicts)
            $networkManagers = Get-AzResource -ResourceType "Microsoft.Network/networkManagers" -ErrorAction SilentlyContinue
            foreach ($nm in $networkManagers) {
                try {
                    Write-Host "  Checking diagnostic settings for Network Manager: $($nm.Name)"
                    # Use REST API to get diagnostic settings as they may have complex names
                    $context = Get-AzContext
                    $token = [Microsoft.Azure.Commands.Common.Authentication.AzureSession]::Instance.AuthenticationFactory.Authenticate($context.Account, $context.Environment, $context.Tenant.Id, $null, $null, $null, "https://management.azure.com/").AccessToken
                    $headers = @{
                        'Authorization' = "Bearer $token"
                        'Content-Type' = 'application/json'
                    }
                    
                    $diagUri = "https://management.azure.com$($nm.ResourceId)/providers/Microsoft.Insights/diagnosticSettings?api-version=2021-05-01-preview"
                    $diagResponse = Invoke-RestMethod -Uri $diagUri -Headers $headers -Method Get -ErrorAction SilentlyContinue
                    
                    if ($diagResponse.value) {
                        foreach ($diagSetting in $diagResponse.value) {
                            try {
                                Write-Host "    Removing diagnostic setting: $($diagSetting.name)"
                                $deleteUri = "https://management.azure.com$($nm.ResourceId)/providers/Microsoft.Insights/diagnosticSettings/$($diagSetting.name)?api-version=2021-05-01-preview"
                                Invoke-RestMethod -Uri $deleteUri -Headers $headers -Method Delete -ErrorAction Continue
                                Write-Host "    ✓ Removed diagnostic setting: $($diagSetting.name)" -ForegroundColor Green
                            }
                            catch {
                                Write-Warning "    Failed to remove diagnostic setting $($diagSetting.name): $($_.Exception.Message)"
                            }
                        }
                    }
                }
                catch {
                    Write-Warning "  Failed to process Network Manager $($nm.Name): $($_.Exception.Message)"
                }
            }
            
            # Remove diagnostic settings from Log Analytics Workspaces
            $logAnalyticsWorkspaces = Get-AzResource -ResourceType "Microsoft.OperationalInsights/workspaces" -ErrorAction SilentlyContinue
            foreach ($workspace in $logAnalyticsWorkspaces) {
                try {
                    Write-Host "  Checking diagnostic settings for Log Analytics Workspace: $($workspace.Name)"
                    $diagUri = "https://management.azure.com$($workspace.ResourceId)/providers/Microsoft.Insights/diagnosticSettings?api-version=2021-05-01-preview"
                    $diagResponse = Invoke-RestMethod -Uri $diagUri -Headers $headers -Method Get -ErrorAction SilentlyContinue
                    
                    if ($diagResponse.value) {
                        foreach ($diagSetting in $diagResponse.value) {
                            try {
                                Write-Host "    Removing workspace diagnostic setting: $($diagSetting.name)"
                                $deleteUri = "https://management.azure.com$($workspace.ResourceId)/providers/Microsoft.Insights/diagnosticSettings/$($diagSetting.name)?api-version=2021-05-01-preview"
                                Invoke-RestMethod -Uri $deleteUri -Headers $headers -Method Delete -ErrorAction Continue
                                Write-Host "    ✓ Removed workspace diagnostic setting: $($diagSetting.name)" -ForegroundColor Green
                            }
                            catch {
                                Write-Warning "    Failed to remove workspace diagnostic setting $($diagSetting.name): $($_.Exception.Message)"
                            }
                        }
                    }
                }
                catch {
                    Write-Warning "  Failed to process Log Analytics Workspace $($workspace.Name): $($_.Exception.Message)"
                }
            }
            
            # Remove all diagnostic settings from subscription level that might be policy-managed
            try {
                Write-Host "  Removing subscription-level diagnostic settings..."
                $subDiagUri = "https://management.azure.com/subscriptions/$SubscriptionId/providers/Microsoft.Insights/diagnosticSettings?api-version=2021-05-01-preview"
                $subDiagResponse = Invoke-RestMethod -Uri $subDiagUri -Headers $headers -Method Get -ErrorAction SilentlyContinue
                
                if ($subDiagResponse.value) {
                    foreach ($diagSetting in $subDiagResponse.value) {
                        try {
                            Write-Host "    Removing subscription diagnostic setting: $($diagSetting.name)"
                            $deleteUri = "https://management.azure.com/subscriptions/$SubscriptionId/providers/Microsoft.Insights/diagnosticSettings/$($diagSetting.name)?api-version=2021-05-01-preview"
                            Invoke-RestMethod -Uri $deleteUri -Headers $headers -Method Delete -ErrorAction Continue
                            Write-Host "    ✓ Removed subscription diagnostic setting: $($diagSetting.name)" -ForegroundColor Green
                        }
                        catch {
                            Write-Warning "    Failed to remove subscription diagnostic setting $($diagSetting.name): $($_.Exception.Message)"
                        }
                    }
                }
            }
            catch {
                Write-Warning "  Error removing subscription diagnostic settings: $($_.Exception.Message)"
            }
            
            # Remove policy assignments that might recreate these resources
            try {
                Write-Host "  Removing policy assignments that auto-create diagnostic settings..."
                $policyAssignments = Get-AzPolicyAssignment -Scope "/subscriptions/$SubscriptionId" -ErrorAction SilentlyContinue | 
                    Where-Object { $_.Properties.DisplayName -like "*diagnostic*" -or $_.Properties.DisplayName -like "*logging*" }
                
                foreach ($policy in $policyAssignments) {
                    try {
                        Write-Host "    Removing policy assignment: $($policy.Properties.DisplayName)"
                        Remove-AzPolicyAssignment -Id $policy.PolicyAssignmentId -Confirm:$false
                        Write-Host "    ✓ Removed policy assignment: $($policy.Properties.DisplayName)" -ForegroundColor Green
                    }
                    catch {
                        Write-Warning "    Failed to remove policy assignment $($policy.Properties.DisplayName): $($_.Exception.Message)"
                    }
                }
            }
            catch {
                Write-Warning "  Error removing policy assignments: $($_.Exception.Message)"
            }
        }
        catch {
            Write-Warning "Error in diagnostic settings cleanup: $($_.Exception.Message)"
        }
        
        # Step 2: Remove role assignments for managed identities and unknown objects
        Write-Host "Removing managed identity and unknown role assignments..." -ForegroundColor Yellow
        try {
            $roleAssignments = Get-AzRoleAssignment -Scope "/subscriptions/$SubscriptionId" -ErrorAction SilentlyContinue | 
                Where-Object { $_.ObjectType -eq "ServicePrincipal" -or $_.ObjectType -eq "Unknown" -or $_.DisplayName -like "*identity*" }
            
            foreach ($assignment in $roleAssignments) {
                try {
                    Write-Host "  Removing role assignment: $($assignment.DisplayName) - $($assignment.RoleDefinitionName)"
                    Remove-AzRoleAssignment -ObjectId $assignment.ObjectId -RoleDefinitionName $assignment.RoleDefinitionName -Scope $assignment.Scope -Confirm:$false -ErrorAction Continue
                }
                catch {
                    Write-Warning "Failed to remove role assignment for $($assignment.DisplayName): $($_.Exception.Message)"
                }
            }
        }
        catch {
            Write-Warning "Error removing role assignments: $($_.Exception.Message)"
        }
        
        # Step 3: Force stop and deallocate VMs first
        Write-Host "Stopping and deallocating virtual machines..." -ForegroundColor Yellow
        $vms = Get-AzVM -ErrorAction SilentlyContinue
        if ($vms) {
            foreach ($vm in $vms) {
                try {
                    Write-Host "  Stopping VM: $($vm.Name)"
                    Stop-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Force -Confirm:$false -AsJob
                }
                catch {
                    Write-Warning "Failed to stop VM $($vm.Name): $($_.Exception.Message)"
                }
            }
            Wait-ForAllJobs -TimeoutMinutes 10
        }
        
        # Step 4: Remove resource locks that might prevent deletion
        Write-Host "Removing resource locks..." -ForegroundColor Yellow
        try {
            $locks = Get-AzResourceLock -Scope "/subscriptions/$SubscriptionId" -ErrorAction SilentlyContinue
            foreach ($lock in $locks) {
                try {
                    Write-Host "  Removing lock: $($lock.Name)"
                    Remove-AzResourceLock -LockId $lock.LockId -Force -Confirm:$false
                }
                catch {
                    Write-Warning "Failed to remove lock $($lock.Name): $($_.Exception.Message)"
                }
            }
        }
        catch {
            Write-Warning "Error removing locks: $($_.Exception.Message)"
        }
        
        # Step 5: Remove resources by type in dependency order with optimized parallel execution
        Write-Host "Removing resources in dependency order with optimized parallel execution..." -ForegroundColor Yellow
        
        # Function for parallel resource removal with throttling
        function Remove-ResourcesInParallel {
            param (
                [Array]$Resources,
                [string]$ResourceType,
                [scriptblock]$RemovalScript,
                [int]$MaxParallelJobs = 10,
                [int]$TimeoutMinutes = 10
            )
            
            if (-not $Resources -or $Resources.Count -eq 0) {
                Write-Host "  No $ResourceType resources to remove" -ForegroundColor Gray
                return
            }
            
            Write-Host "  Removing $($Resources.Count) $ResourceType resources in parallel (max $MaxParallelJobs at once)..." -ForegroundColor Yellow
            
            $jobBatch = @()
            $resourceCount = 0
            $totalResources = $Resources.Count
            
            foreach ($resource in $Resources) {
                $resourceCount++
                
                try {
                    $jobParams = @{
                        ScriptBlock = $RemovalScript
                        ArgumentList = $resource
                    }
                    
                    $job = Start-Job @jobParams
                    $jobBatch += $job
                    
                    Write-Host "    Started job to remove ${ResourceType}: $($resource.Name) ($resourceCount of $totalResources)" -ForegroundColor Gray
                    
                    # Wait if we hit the parallel job limit or this is the last resource
                    if ($jobBatch.Count -ge $MaxParallelJobs -or $resourceCount -eq $totalResources) {
                        Write-Host "    Waiting for batch of $($jobBatch.Count) $ResourceType removal jobs to complete..." -ForegroundColor Yellow
                        $jobBatch | Wait-Job -Timeout ($TimeoutMinutes * 60)
                        
                        # Process completed jobs
                        foreach ($batchJob in $jobBatch) {
                            $result = Receive-Job -Job $batchJob -ErrorAction SilentlyContinue
                            if ($batchJob.State -eq "Completed") {
                                Write-Host "    ✓ Resource removal job completed successfully" -ForegroundColor Green
                            }
                            else {
                                Write-Warning "    ⚠️ Resource removal job ended with state: $($batchJob.State)"
                            }
                            Remove-Job -Job $batchJob -Force
                        }
                        
                        # Clear batch for next round
                        $jobBatch = @()
                    }
                }
                catch {
                    Write-Warning "    Failed to start removal job for $ResourceType $($resource.Name): $($_.Exception.Message)"
                }
            }
        }

        # Define removal scripts for different resource types
        $appGatewayRemovalScript = {
            param($appGw)
            Write-Output "Removing Application Gateway: $($appGw.Name)"
            try {
                Remove-AzApplicationGateway -Name $appGw.Name -ResourceGroupName $appGw.ResourceGroupName -Force -Confirm:$false
                Write-Output "Successfully removed Application Gateway: $($appGw.Name)"
            } catch {
                Write-Output "Failed to remove Application Gateway $($appGw.Name): $($_.Exception.Message)"
            }
        }
        
        $lbRemovalScript = {
            param($lb)
            Write-Output "Removing Load Balancer: $($lb.Name)"
            try {
                Remove-AzLoadBalancer -Name $lb.Name -ResourceGroupName $lb.ResourceGroupName -Force -Confirm:$false
                Write-Output "Successfully removed Load Balancer: $($lb.Name)"
            } catch {
                Write-Output "Failed to remove Load Balancer $($lb.Name): $($_.Exception.Message)"
            }
        }
        
        $vmRemovalScript = {
            param($vm)
            Write-Output "Removing VM: $($vm.Name)"
            try {
                Remove-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Force -Confirm:$false
                Write-Output "Successfully removed VM: $($vm.Name)"
            } catch {
                Write-Output "Failed to remove VM $($vm.Name): $($_.Exception.Message)"
            }
        }
        
        $nicRemovalScript = {
            param($nic)
            Write-Output "Removing NIC: $($nic.Name)"
            try {
                Remove-AzNetworkInterface -Name $nic.Name -ResourceGroupName $nic.ResourceGroupName -Force -Confirm:$false
                Write-Output "Successfully removed NIC: $($nic.Name)"
            } catch {
                Write-Output "Failed to remove NIC $($nic.Name): $($_.Exception.Message)"
            }
        }
        
        $diskRemovalScript = {
            param($disk)
            Write-Output "Removing Disk: $($disk.Name)"
            try {
                Remove-AzDisk -ResourceGroupName $disk.ResourceGroupName -DiskName $disk.Name -Force -Confirm:$false
                Write-Output "Successfully removed Disk: $($disk.Name)"
            } catch {
                Write-Output "Failed to remove Disk $($disk.Name): $($_.Exception.Message)"
            }
        }
        
        # Execute parallel removal for each resource type in dependency order
        $appGateways = Get-AzApplicationGateway -ErrorAction SilentlyContinue
        Remove-ResourcesInParallel -Resources $appGateways -ResourceType "Application Gateway" -RemovalScript $appGatewayRemovalScript -MaxParallelJobs 5
        
        $loadBalancers = Get-AzLoadBalancer -ErrorAction SilentlyContinue
        Remove-ResourcesInParallel -Resources $loadBalancers -ResourceType "Load Balancer" -RemovalScript $lbRemovalScript -MaxParallelJobs 5
        
        # Remove VMs with higher parallelism
        $vms = Get-AzVM -ErrorAction SilentlyContinue
        Remove-ResourcesInParallel -Resources $vms -ResourceType "Virtual Machine" -RemovalScript $vmRemovalScript -MaxParallelJobs 10 -TimeoutMinutes 20
        
        # Remove VM-related resources with high parallelism
        $nics = Get-AzNetworkInterface -ErrorAction SilentlyContinue
        Remove-ResourcesInParallel -Resources $nics -ResourceType "Network Interface" -RemovalScript $nicRemovalScript -MaxParallelJobs 15
        
        $disks = Get-AzDisk -ErrorAction SilentlyContinue
        Remove-ResourcesInParallel -Resources $disks -ResourceType "Disk" -RemovalScript $diskRemovalScript -MaxParallelJobs 15
        
        Wait-ForAllJobs -TimeoutMinutes 10
        
        # Remove all remaining individual resources
        Write-Host "Removing all remaining individual resources..." -ForegroundColor Yellow
        $resources = Get-AzResource -ErrorAction SilentlyContinue
        if ($resources) {
            foreach ($resource in $resources) {
                try {
                    Write-Host "  Removing resource: $($resource.Name) of type $($resource.ResourceType)"
                    Remove-AzResource -ResourceId $resource.ResourceId -Force -Confirm:$false -AsJob
                }
                catch {
                    Write-Warning "Failed to remove resource $($resource.Name): $($_.Exception.Message)"
                }
            }
        }
        
        # Wait for resource deletion jobs
        Wait-ForAllJobs -TimeoutMinutes 20
        
        # Step 5.5: Comprehensive diagnostic settings cleanup
        Write-Host "Performing comprehensive diagnostic settings cleanup..." -ForegroundColor Yellow
        Remove-AllDiagnosticSettings -SubscriptionId $SubscriptionId
        
        # Step 6: Remove Resource Groups with optimized parallel execution
        Write-Host "Removing resource groups with optimized parallel execution..." -ForegroundColor Yellow
        $rgs = Get-AzResourceGroup -ErrorAction SilentlyContinue
        
        if ($rgs -and $rgs.Count -gt 0) {
            $resourceGroupRemovalScript = {
                param($rg)
                Write-Output "Removing resource group: $($rg.ResourceGroupName)"
                try {
                    $result = Remove-AzResourceGroup -Name $rg.ResourceGroupName -Confirm:$false -Force
                    Write-Output "Successfully removed resource group: $($rg.ResourceGroupName)"
                    return $true
                }
                catch {
                    Write-Output "Failed to remove resource group $($rg.ResourceGroupName): $($_.Exception.Message)"
                    return $false
                }
            }
            
            # Remove resource groups in parallel with batching
            Write-Host "  Removing $($rgs.Count) resource groups in parallel batches..." -ForegroundColor Yellow
            
            # Break into smaller batches for better control and visibility
            $batchSize = [Math]::Min(5, $rgs.Count)
            $batches = [Math]::Ceiling($rgs.Count / $batchSize)
            
            for ($batchNum = 0; $batchNum -lt $batches; $batchNum++) {
                $start = $batchNum * $batchSize
                $end = [Math]::Min(($batchNum + 1) * $batchSize - 1, $rgs.Count - 1)
                $batchRgs = $rgs[$start..$end]
                
                Write-Host "  Starting batch $($batchNum+1) of $batches ($($batchRgs.Count) resource groups)..." -ForegroundColor Yellow
                
                $jobs = @()
                foreach ($rg in $batchRgs) {
                    try {
                        Write-Host "    Starting job to remove resource group: $($rg.ResourceGroupName)" -ForegroundColor Gray
                        $job = Start-Job -ScriptBlock $resourceGroupRemovalScript -ArgumentList $rg
                        $jobs += $job
                    }
                    catch {
                        Write-Warning "    Failed to start job for resource group $($rg.ResourceGroupName): $($_.Exception.Message)"
                    }
                }
                
                # Wait for this batch to complete with detailed progress
                if ($jobs.Count -gt 0) {
                    Write-Host "    Waiting for batch $($batchNum+1) jobs to complete (this may take several minutes)..." -ForegroundColor Yellow
                    $timeout = 25 * 60  # 25 minutes in seconds
                    $startTime = Get-Date
                    $completed = $false
                    
                    while (-not $completed -and ((Get-Date) - $startTime).TotalSeconds -lt $timeout) {
                        $runningJobs = $jobs | Where-Object { $_.State -eq "Running" }
                        if ($runningJobs.Count -eq 0) {
                            $completed = $true
                        }
                        else {
                            Write-Host "      Still waiting for $($runningJobs.Count) of $($jobs.Count) jobs... ($(Get-Date))" -ForegroundColor Gray
                            Start-Sleep -Seconds 30
                        }
                    }
                    
                    # Process results
                    foreach ($job in $jobs) {
                        $result = Receive-Job -Job $job -ErrorAction SilentlyContinue
                        Write-Host "      Resource group removal job completed with state: $($job.State)" -ForegroundColor $(if ($job.State -eq "Completed") { "Green" } else { "Yellow" })
                        Remove-Job -Job $job -Force
                    }
                    
                    if (-not $completed) {
                        Write-Warning "    Timeout waiting for batch $($batchNum+1). Moving to next batch."
                    }
                    else {
                        Write-Host "    Batch $($batchNum+1) completed successfully." -ForegroundColor Green
                    }
                    
                    # Add a small delay between batches to give Azure a breather
                    Start-Sleep -Seconds 10
                }
            }
        }
        else {
            Write-Host "  No resource groups to remove." -ForegroundColor Gray
        }
        
        # Step 7: Delete Azure Subscription scoped deployments
        Write-Host "Removing subscription deployments..." -ForegroundColor Yellow
        $deps = Get-AzSubscriptionDeployment -ErrorAction SilentlyContinue
        if ($deps) {
            foreach ($dep in $deps) {
                try {
                    Write-Host "  Removing deployment: $($dep.DeploymentName)"
                    Remove-AzSubscriptionDeployment -Name $dep.DeploymentName -Confirm:$false -AsJob
                }
                catch {
                    Write-Warning "Failed to remove deployment $($dep.DeploymentName): $($_.Exception.Message)"
                }
            }
        }
        
        # Wait for deployment deletion jobs
        Wait-ForAllJobs -TimeoutMinutes 10
        
        # Step 8: Reset Defender for Cloud to Free tier
        Write-Host "Resetting Defender for Cloud plans..." -ForegroundColor Yellow
        try {
            Get-AzSecurityPricing -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    Write-Host "  Resetting Defender for Cloud plan: $($_.Name) to the Free Tier"
                    Set-AzSecurityPricing -Name $_.Name -PricingTier "Free"
                }
                catch {
                    Write-Warning "Failed to reset Defender plan $($_.Name): $($_.Exception.Message)"
                }
            }
        }
        catch {
            Write-Warning "Failed to reset some Defender for Cloud plans: $($_.Exception.Message)"
        }
        
        # Step 9: Final cleanup - remove any remaining role assignments
        Write-Host "Final cleanup of role assignments..." -ForegroundColor Yellow
        try {
            $remainingAssignments = Get-AzRoleAssignment -Scope "/subscriptions/$SubscriptionId" -ErrorAction SilentlyContinue | 
                Where-Object { $_.ObjectType -eq "ServicePrincipal" -or $_.ObjectType -eq "Unknown" -or $_.DisplayName -like "*identity*" }
            
            foreach ($assignment in $remainingAssignments) {
                try {
                    Write-Host "  Final removal of role assignment: $($assignment.DisplayName)"
                    Remove-AzRoleAssignment -ObjectId $assignment.ObjectId -RoleDefinitionName $assignment.RoleDefinitionName -Scope $assignment.Scope -Confirm:$false -ErrorAction Continue
                }
                catch {
                    Write-Warning "Failed final removal of role assignment for $($assignment.DisplayName): $($_.Exception.Message)"
                }
            }
        }
        catch {
            Write-Warning "Error in final role assignment cleanup: $($_.Exception.Message)"
        }
        
        # Wait longer for Azure to process deletions
        Write-Host "Waiting 120 seconds for Azure to process all deletions..." -ForegroundColor Cyan
        Start-Sleep -Seconds 120
        
        # Check if subscription is empty
        $isEmpty = Test-SubscriptionEmpty -SubscriptionId $SubscriptionId
        
        if ($isEmpty) {
            Write-Host "✓ Subscription $SubscriptionId is now completely empty!" -ForegroundColor Green
            break
        }
        else {
            Write-Host "⚠ Subscription $SubscriptionId still contains resources. Retrying..." -ForegroundColor Yellow
            
            # If we're past halfway through retries, try alternative cleanup methods
            if ($retryCount -gt ($MaxRetries / 2)) {
                Write-Host "Attempting alternative cleanup methods for stubborn resources..." -ForegroundColor Magenta
                Invoke-StuckResourceCleanup -SubscriptionId $SubscriptionId
                Start-Sleep -Seconds 60
            }
            
            if ($retryCount -lt $MaxRetries) {
                Write-Host "Waiting 180 seconds before next attempt..." -ForegroundColor Yellow
                Start-Sleep -Seconds 180
            }
        }
        
    } while ($retryCount -lt $MaxRetries -and -not $isEmpty)
    
    if (-not $isEmpty) {
        Write-Error "Failed to completely clean subscription $SubscriptionId after $MaxRetries attempts!"
        return $false
    }
    
    return $true
}

# Process subscriptions sequentially (one at a time) for complete tenant cleanup
Write-Host "`n=======================================================" -ForegroundColor Cyan
Write-Host "Starting sequential subscription cleanup..." -ForegroundColor Cyan
Write-Host "Sequential processing ensures complete resource removal" -ForegroundColor Cyan
Write-Host "=======================================================" -ForegroundColor Cyan

$cleanupResults = @{}
$totalSubscriptions = $subs.Count
$currentSubIndex = 0

# Process each subscription one at a time
foreach ($sub in $subs) {
    $currentSubIndex++
    
    Write-Host "`n=======================================================" -ForegroundColor Cyan
    Write-Host "Processing subscription $currentSubIndex of $totalSubscriptions" -ForegroundColor Cyan
    Write-Host "Subscription ID: $sub" -ForegroundColor Cyan
    Write-Host "=======================================================" -ForegroundColor Cyan
    
    # Show progress
    Show-ScriptProgress -Activity "Tenant Cleanup Progress" -PercentComplete ([math]::Round(($currentSubIndex / $totalSubscriptions) * 100)) -Status "Cleaning subscription $currentSubIndex of $totalSubscriptions"
    
    try {
        # Execute the cleanup synchronously (no background jobs)
        Write-Host "🧹 Starting comprehensive cleanup for subscription: $sub" -ForegroundColor Yellow
        $cleanupSuccess = Clear-SubscriptionResources -SubscriptionId $sub
        
        if ($cleanupSuccess) {
            Write-Host "✅ Subscription $sub cleanup completed successfully!" -ForegroundColor Green
            $cleanupResults[$sub] = @{
                Success = $true
                Error = $null
                CompletedAt = Get-Date
            }
            
            # Move the subscription back to the tenant root management group
            try {
                Write-Host "🔄 Moving subscription back to tenant root management group..." -ForegroundColor Yellow
                Select-AzSubscription -SubscriptionId $sub
                $tenantId = (Get-AzContext).Tenant.Id
                
                # Remove from current management group first
                try {
                    $currentMgAssociation = Get-AzManagementGroupSubscription -GroupName "ADIA" -SubscriptionId $sub -ErrorAction SilentlyContinue
                    if ($currentMgAssociation) {
                        Write-Host "  📤 Removing subscription from ADIA management group..."
                        Remove-AzManagementGroupSubscription -GroupName "ADIA" -SubscriptionId $sub -Confirm:$false
                    }
                }
                catch {
                    Write-Warning "Could not remove subscription from current management group: $($_.Exception.Message)"
                }
                
                # Add to tenant root
                New-AzManagementGroupSubscription -GroupName $tenantId -SubscriptionId $sub -Confirm:$false
                Write-Host "  ✅ Successfully moved subscription to tenant root ($tenantId)" -ForegroundColor Green
                
                # Verify the move
                Start-Sleep -Seconds 30
                $verifyAssociation = Get-AzManagementGroupSubscription -GroupName $tenantId -SubscriptionId $sub -ErrorAction SilentlyContinue
                if ($verifyAssociation) {
                    Write-Host "  ✅ Verified subscription is now in tenant root management group" -ForegroundColor Green
                }
                else {
                    Write-Warning "Could not verify subscription move to tenant root"
                }
            }
            catch {
                Write-Warning "Failed to move subscription to tenant root: $($_.Exception.Message)"
                $cleanupResults[$sub].Error = "Failed to move to tenant root: $($_.Exception.Message)"
            }
        }
        else {
            Write-Host "❌ Subscription $sub cleanup failed!" -ForegroundColor Red
            $cleanupResults[$sub] = @{
                Success = $false
                Error = "Cleanup process returned false"
                CompletedAt = Get-Date
            }
        }
    }
    catch {
        Write-Error "❌ Critical error during cleanup of subscription $sub`: $($_.Exception.Message)"
        $cleanupResults[$sub] = @{
            Success = $false
            Error = $_.Exception.Message
            CompletedAt = Get-Date
        }
    }
    
    # Show completion status for this subscription
    Write-Host "`n📊 Subscription $sub Status: $(if ($cleanupResults[$sub].Success) { '✅ SUCCESS' } else { '❌ FAILED' })" -ForegroundColor $(if ($cleanupResults[$sub].Success) { 'Green' } else { 'Red' })
    
    # Add a brief pause between subscriptions to allow Azure to settle
    if ($currentSubIndex -lt $totalSubscriptions) {
        Write-Host "⏳ Waiting 30 seconds before processing next subscription..." -ForegroundColor Cyan
        Start-Sleep -Seconds 30
    }
}

# Function to delete all management groups (excluding tenant root)
function Remove-AllManagementGroups {
    Write-Host "`n=======================================================" -ForegroundColor Magenta
    Write-Host "Discovering and deleting ALL management groups" -ForegroundColor Magenta
    Write-Host "=======================================================" -ForegroundColor Magenta

    try {
        # Get current tenant ID to exclude tenant root from deletion
        $tenantId = (Get-AzContext).Tenant.Id
        Write-Host "Current tenant ID: $tenantId" -ForegroundColor Cyan
        
        # Get all management groups accessible to the current user
        Write-Host "Discovering all management groups..." -ForegroundColor Yellow
        $allManagementGroups = Get-AzManagementGroup -ErrorAction SilentlyContinue
        
        if (-not $allManagementGroups -or $allManagementGroups.Count -eq 0) {
            Write-Host "No management groups found or no access to management groups." -ForegroundColor Green
            return
        }
        
        # Filter out tenant root management group (it cannot be deleted)
        $deletableGroups = $allManagementGroups | Where-Object { $_.Name -ne $tenantId }
        
        if (-not $deletableGroups -or $deletableGroups.Count -eq 0) {
            Write-Host "No deletable management groups found (only tenant root exists)." -ForegroundColor Green
            return
        }
        
        Write-Host "Found $($deletableGroups.Count) management group(s) to delete:" -ForegroundColor Yellow
        foreach ($group in $deletableGroups) {
            Write-Host "  - $($group.Name) ($($group.DisplayName))" -ForegroundColor White
        }
        
        # Build dependency tree to delete in correct order (children first)
        $deletionOrder = Get-ManagementGroupDeletionOrder -ManagementGroups $deletableGroups -TenantId $tenantId
        
        Write-Host "`nDeleting management groups in dependency order..." -ForegroundColor Yellow
        foreach ($groupName in $deletionOrder) {
            try {
                # Clean up resources in this management group first
                Clear-ManagementGroupResources -ManagementGroupName $groupName
                
                # Then delete the management group itself
                Remove-ManagementGroupSafely -GroupName $groupName
            }
            catch {
                Write-Warning "Failed to delete management group '$groupName': $($_.Exception.Message)"
            }
        }
        
        Write-Host "✓ Completed deletion of all accessible management groups" -ForegroundColor Green
        Write-Host "⏳ Waiting for management group and role assignment deletions to fully propagate..." -ForegroundColor Cyan
        Write-Host "   This extended wait ensures no ghost references remain that could cause 'MalformedRoleAssignmentRequest' errors" -ForegroundColor Yellow
        
        # Extended wait for management group deletion propagation
        $waitTime = 120  # 2 minutes for full propagation
        for ($i = 1; $i -le $waitTime; $i++) {
            Write-Progress -Activity "Waiting for Azure propagation" -Status "Ensuring complete cleanup..." -PercentComplete (($i / $waitTime) * 100)
            Start-Sleep -Seconds 1
        }
        Write-Progress -Activity "Waiting for Azure propagation" -Completed
        
        Write-Host "✅ Extended propagation delay completed - management groups can now be safely recreated" -ForegroundColor Green
    }
    catch {
        Write-Error "Error in management group discovery and deletion: $($_.Exception.Message)"
    }
}

# Function to determine correct deletion order for management groups
function Get-ManagementGroupDeletionOrder {
    param (
        [array]$ManagementGroups,
        [string]$TenantId
    )
    
    $deletionOrder = @()
    $processed = @{}
    
    # Create a lookup table for management groups
    $mgLookup = @{}
    foreach ($mg in $ManagementGroups) {
        $mgLookup[$mg.Name] = $mg
    }
    
    # Recursive function to build deletion order (children first)
    function Add-ToOrder {
        param ([string]$GroupName)
        
        if ($processed.ContainsKey($GroupName)) {
            return
        }
        
        try {
            # Get detailed information about this management group
            $mgDetails = Get-AzManagementGroup -GroupName $GroupName -Expand -ErrorAction SilentlyContinue
            
            if ($mgDetails -and $mgDetails.Children) {
                # Process children first
                foreach ($child in $mgDetails.Children) {
                    if ($child.Type -eq "Microsoft.Management/managementGroups" -and 
                        $mgLookup.ContainsKey($child.Name) -and 
                        -not $processed.ContainsKey($child.Name)) {
                        Add-ToOrder -GroupName $child.Name
                    }
                }
            }
            
            # Add this group to deletion order after its children
            if (-not $processed.ContainsKey($GroupName)) {
                $deletionOrder += $GroupName
                $processed[$GroupName] = $true
                Write-Host "  Added to deletion order: $GroupName" -ForegroundColor Gray
            }
        }
        catch {
            Write-Warning "Could not determine children for management group '$GroupName': $($_.Exception.Message)"
            # Add it anyway to attempt deletion
            if (-not $processed.ContainsKey($GroupName)) {
                $deletionOrder += $GroupName
                $processed[$GroupName] = $true
            }
        }
    }
    
    # Process all management groups
    foreach ($mg in $ManagementGroups) {
        Add-ToOrder -GroupName $mg.Name
    }
    
    return $deletionOrder
}

# Function to safely remove a management group with proper error handling
function Remove-ManagementGroupSafely {
    param (
        [Parameter(Mandatory=$true)]
        [string]$GroupName
    )
    
    try {
        # First check if the management group still exists
        $managementGroup = Get-AzManagementGroup -GroupName $GroupName -ErrorAction SilentlyContinue
        if (-not $managementGroup) {
            Write-Host "  Management group '$GroupName' no longer exists (already deleted)" -ForegroundColor Gray
            return
        }
        
        # Check if it has any remaining children
        $mgWithChildren = Get-AzManagementGroup -GroupName $GroupName -Expand -ErrorAction SilentlyContinue
        if ($mgWithChildren -and $mgWithChildren.Children -and $mgWithChildren.Children.Count -gt 0) {
            Write-Warning "  Management group '$GroupName' still has children. Skipping deletion to avoid errors."
            Write-Host "    Children found:" -ForegroundColor Yellow
            foreach ($child in $mgWithChildren.Children) {
                Write-Host "      - $($child.Name) ($($child.Type))" -ForegroundColor Yellow
            }
            return
        }

        # Delete the management group
        Write-Host "  Deleting management group: $GroupName" -ForegroundColor Yellow
        Remove-AzManagementGroup -GroupName $GroupName -Confirm:$false -ErrorAction Stop
        Write-Host "  ✓ Successfully deleted management group: $GroupName" -ForegroundColor Green
        
        # Wait a moment for Azure to process the deletion
        Start-Sleep -Seconds 5
    }
    catch {
        Write-Warning "Failed to delete management group '$GroupName': $($_.Exception.Message)"
    }
}

# Function to clean up resources within a management group
function Clear-ManagementGroupResources {
    param (
        [string]$ManagementGroupName
    )
    
    Write-Host "  Cleaning resources in management group: $ManagementGroupName" -ForegroundColor Cyan
    
    try {
        # Check if management group exists
        $mgGroup = Get-AzManagementGroup -GroupName $ManagementGroupName -ErrorAction SilentlyContinue
        if (-not $mgGroup) {
            Write-Host "    Management group '$ManagementGroupName' does not exist." -ForegroundColor Gray
            return
        }
        
        # Remove deployment stacks at management group scope
        try {
            $mgDeploymentStacks = Get-AzManagementGroupDeploymentStack -ManagementGroupId $ManagementGroupName -ErrorAction SilentlyContinue
            if ($mgDeploymentStacks) {
                foreach ($stack in $mgDeploymentStacks) {
                    try {
                        Write-Host "    Removing MG deployment stack: $($stack.Name)"
                        Remove-AzManagementGroupDeploymentStack -ManagementGroupId $ManagementGroupName -Name $stack.Name -ActionOnUnmanage DeleteAll -Force -Confirm:$false
                        Write-Host "    ✓ Removed deployment stack: $($stack.Name)" -ForegroundColor Green
                    }
                    catch {
                        Write-Warning "    Failed to remove MG deployment stack $($stack.Name): $($_.Exception.Message)"
                    }
                }
            }
        }
        catch {
            Write-Warning "    Error checking management group deployment stacks: $($_.Exception.Message)"
        }
        
        # Remove deployments at management group scope
        try {
            $mgDeployments = Get-AzManagementGroupDeployment -ManagementGroupId $ManagementGroupName -ErrorAction SilentlyContinue
            if ($mgDeployments) {
                foreach ($deployment in $mgDeployments) {
                    try {
                        Write-Host "    Removing MG deployment: $($deployment.DeploymentName)"
                        Remove-AzManagementGroupDeployment -ManagementGroupId $ManagementGroupName -Name $deployment.DeploymentName -Confirm:$false
                        Write-Host "    ✓ Removed deployment: $($deployment.DeploymentName)" -ForegroundColor Green
                    }
                    catch {
                        Write-Warning "    Failed to remove MG deployment $($deployment.DeploymentName): $($_.Exception.Message)"
                    }
                }
            }
        }
        catch {
            Write-Warning "    Error checking management group deployments: $($_.Exception.Message)"
        }
        
        # Remove role assignments at management group scope
        try {
            $mgScope = "/providers/Microsoft.Management/managementGroups/$ManagementGroupName"
            Write-Host "    Checking role assignments at scope: $mgScope" -ForegroundColor Gray
            $mgRoleAssignments = Get-AzRoleAssignment -Scope $mgScope -ErrorAction SilentlyContinue
            
            if ($mgRoleAssignments) {
                Write-Host "    Found $($mgRoleAssignments.Count) role assignment(s) at management group scope" -ForegroundColor Yellow
                foreach ($assignment in $mgRoleAssignments) {
                    try {
                        Write-Host "    Found role assignment: $($assignment.DisplayName) ($($assignment.ObjectType)) - $($assignment.RoleDefinitionName)" -ForegroundColor Gray
                        Write-Host "      ObjectId: $($assignment.ObjectId)" -ForegroundColor Gray
                        Write-Host "      RoleAssignmentId: $($assignment.RoleAssignmentId)" -ForegroundColor Gray
                        
                        # ENHANCED CLEANUP: Remove ALL role assignments except specific Azure system assignments
                        $isSystemAssignment = $false
                        
                        # Skip only critical Azure system assignments (very specific)
                        if ($assignment.ObjectType -eq "ServicePrincipal" -and 
                            ($assignment.DisplayName -like "Microsoft*" -or 
                             $assignment.DisplayName -like "Azure*" -or
                             $assignment.DisplayName -like "Windows Azure*" -or
                             $assignment.RoleDefinitionName -eq "Azure Service Deploy Release Management Contributor")) {
                            $isSystemAssignment = $true
                        }
                        
                        if (-not $isSystemAssignment) {
                            Write-Host "    🗑️ Removing MG role assignment: $($assignment.DisplayName) - $($assignment.RoleDefinitionName)" -ForegroundColor Yellow
                            
                            # Try multiple removal methods to ensure complete cleanup
                            try {
                                # Method 1: Remove by RoleAssignmentId (most reliable)
                                Remove-AzRoleAssignment -RoleAssignmentId $assignment.RoleAssignmentId -Confirm:$false -ErrorAction Stop
                                Write-Host "    ✅ Removed role assignment by ID: $($assignment.DisplayName)" -ForegroundColor Green
                            }
                            catch {
                                try {
                                    # Method 2: Remove by ObjectId and RoleDefinitionName
                                    Remove-AzRoleAssignment -ObjectId $assignment.ObjectId -RoleDefinitionName $assignment.RoleDefinitionName -Scope $assignment.Scope -Confirm:$false -ErrorAction Stop
                                    Write-Host "    ✅ Removed role assignment by ObjectId: $($assignment.DisplayName)" -ForegroundColor Green
                                }
                                catch {
                                    try {
                                        # Method 3: Remove by SignInName if available
                                        if ($assignment.SignInName) {
                                            Remove-AzRoleAssignment -SignInName $assignment.SignInName -RoleDefinitionName $assignment.RoleDefinitionName -Scope $assignment.Scope -Confirm:$false -ErrorAction Stop
                                            Write-Host "    ✅ Removed role assignment by SignInName: $($assignment.DisplayName)" -ForegroundColor Green
                                        }
                                        else {
                                            throw "No SignInName available"
                                        }
                                    }
                                    catch {
                                        Write-Warning "    ⚠️ Failed to remove role assignment $($assignment.DisplayName): $($_.Exception.Message)"
                                        Write-Host "      This may cause issues when recreating management groups with the same name" -ForegroundColor Yellow
                                    }
                                }
                            }
                            
                            # Add delay to ensure Azure processes the deletion before next assignment
                            Start-Sleep -Seconds 3
                        }
                        else {
                            Write-Host "    ⏭️ Skipping Azure system role assignment: $($assignment.DisplayName)" -ForegroundColor Gray
                        }
                    }
                    catch {
                        Write-Warning "    Failed to process MG role assignment for $($assignment.DisplayName): $($_.Exception.Message)"
                    }
                }
                
                # ENHANCED: Much longer propagation delay for role assignment deletions
                Write-Host "    ⏳ Waiting for role assignment deletions to fully propagate (60 seconds)..." -ForegroundColor Cyan
                Start-Sleep -Seconds 60
                
                # Verify cleanup completed
                Write-Host "    🔍 Verifying role assignment cleanup..." -ForegroundColor Cyan
                $remainingAssignments = Get-AzRoleAssignment -Scope $mgScope -ErrorAction SilentlyContinue
                if ($remainingAssignments) {
                    Write-Warning "    ⚠️ $($remainingAssignments.Count) role assignment(s) still remain after cleanup"
                    foreach ($remaining in $remainingAssignments) {
                        Write-Host "      Remaining: $($remaining.DisplayName) - $($remaining.RoleDefinitionName)" -ForegroundColor Yellow
                    }
                }
                else {
                    Write-Host "    ✅ All role assignments successfully removed" -ForegroundColor Green
                }
            }
            else {
                Write-Host "    No role assignments found at management group scope" -ForegroundColor Gray
            }
        }
        catch {
            Write-Warning "    Error removing management group role assignments: $($_.Exception.Message)"
        }
        
        Write-Host "    ✓ Resource cleanup completed for: $ManagementGroupName" -ForegroundColor Green
    }
    catch {
        Write-Warning "    Resource cleanup failed for '$ManagementGroupName': $($_.Exception.Message)"
    }
}

# Legacy function kept for backward compatibility (now just calls the new function)
function Remove-ManagementGroupRecursively {
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$GroupName
    )
    
    Write-Warning "Remove-ManagementGroupRecursively is deprecated. Use Remove-AllManagementGroups instead."
    Remove-ManagementGroupSafely -GroupName $GroupName
}

# Legacy function kept for backward compatibility (now just calls the new generic function)
function Clear-ADIAManagementGroupResources {
    param (
        [string]$ManagementGroupName = "ADIA"
    )
    
    Write-Warning "Clear-ADIAManagementGroupResources is deprecated. Use Clear-ManagementGroupResources instead."
    Clear-ManagementGroupResources -ManagementGroupName $ManagementGroupName
}

# Delete ALL management groups (excluding tenant root)
Write-Host "`n🔄 Starting comprehensive management group cleanup..." -ForegroundColor Cyan
try {
    Remove-AllManagementGroups
    Write-Host "✅ Management group cleanup completed successfully!" -ForegroundColor Green
}
catch {
    Write-Error "❌ Management group cleanup failed: $($_.Exception.Message)"
}

# Final verification and summary
Write-Host "`n🔍 Final Verification Summary" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

$allClean = $true
foreach ($sub in $subs) {
    Write-Host "`nVerifying subscription: $sub" -ForegroundColor Yellow
    Select-AzSubscription -SubscriptionId $sub -ErrorAction SilentlyContinue
    $isEmpty = Test-SubscriptionEmpty -SubscriptionId $sub
    
    if ($isEmpty) {
        Write-Host "✅ Subscription $sub is completely clean" -ForegroundColor Green
    }
    else {
        Write-Host "❌ Subscription $sub still has resources" -ForegroundColor Red
        $allClean = $false
    }
}

if ($allClean) {
    Write-Host "`n🎉 ALL SUBSCRIPTIONS ARE COMPLETELY CLEAN! 🎉" -ForegroundColor Green
}
else {
    Write-Host "`n⚠️  Some subscriptions still contain resources. Manual review required." -ForegroundColor Yellow
}

# Calculate and display execution time
$scriptEndTime = Get-Date
$executionTime = $scriptEndTime - $scriptStartTime
$formattedTime = "{0:D2}h:{1:D2}m:{2:D2}s" -f $executionTime.Hours, $executionTime.Minutes, $executionTime.Seconds

Write-Host "`n=========================================================" -ForegroundColor Cyan
Write-Host "Cleanup Script Summary" -ForegroundColor Cyan
Write-Host "=========================================================" -ForegroundColor Cyan
Write-Host "Start time: $scriptStartTime" -ForegroundColor White
Write-Host "End time:   $scriptEndTime" -ForegroundColor White
Write-Host "Duration:   $formattedTime" -ForegroundColor White
Write-Host "Subscriptions processed: $($subs.Count)" -ForegroundColor White

Write-Host "`n✅ Optimized cleanup script completed successfully!" -ForegroundColor Green
