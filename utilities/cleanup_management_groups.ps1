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

 
foreach ($sub in $subs) {
    Select-AzSubscription -SubscriptionId $sub
    Write-Host "Processing subscription: $($sub) now"
 
    # Remove Resource Groups and their resources from the subscription
    $rgs = Get-AzResourceGroup
    $rgs | ForEach-Object -Parallel {
        Remove-AzResourceGroup -Name $_.ResourceGroupName -Confirm:$false -Force -AsJob
 
    }
 
    # Delete Azure Subscription scoped deployments
    $deps = Get-AzSubscriptionDeployment
    $deps | ForEach-Object -Parallel {
        Remove-AzSubscriptionDeployment -Name $_.DeploymentName -Confirm:$false -AsJob
    }
 
    Get-AzSecurityPricing | ForEach-Object -Parallel {
        Write-Output "Resetting Defender for Cloud plan: $($_.Name) to the Free Tier"
        Set-AzSecurityPricing -Name $_.Name -PricingTier "Free"
    }
 
    # Move the subscription back to the tenant root management group
    New-AzManagementGroupSubscription -GroupName (Get-AzContext).Tenant.Id -SubscriptionId $sub -Confirm:$false -Verbose
}

# Function to recursively delete management groups
function Remove-ManagementGroupRecursively {
    param (
        [string]$GroupName
    )

    $children = Get-AzManagementGroup -GroupName $GroupName -Expand | Select-Object -ExpandProperty Children
    if ($children) {
        foreach ($child in $children) {
            Remove-ManagementGroupRecursively -GroupName $child.Name
        }
    }

    Write-Host "Deleting management group: $GroupName"
    Remove-AzManagementGroup -GroupName $GroupName -Confirm:$false
}

# Delete all management groups under 'ADIA'
Remove-ManagementGroupRecursively -GroupName 'ADIA'