# Validate-PolicyAssignments.ps1
# This script validates that all required Azure policies are assigned to the specified management groups.

param (
    [string]$ManagementGroupId,
    [string[]]$RequiredPolicies
)

# Import Azure module
Import-Module Az.Resources

# Authenticate and ensure the user is logged in
if (-not (Get-AzContext)) {
    Write-Error "Please login to Azure using Connect-AzAccount."
    exit 1
}

# Fetch assigned policies for the management group
$assignedPolicies = Get-AzPolicyAssignment -ManagementGroupName $ManagementGroupId

# Validate each required policy
$missingPolicies = @()
foreach ($policy in $RequiredPolicies) {
    if (-not ($assignedPolicies | Where-Object { $_.PolicyDefinitionId -like "*$policy*" })) {
        $missingPolicies += $policy
    }
}

# Output results
if ($missingPolicies.Count -eq 0) {
    Write-Output "All required policies are assigned to the management group: $ManagementGroupId."
    exit 0
} else {
    Write-Error "The following policies are missing from the management group: $ManagementGroupId"
    $missingPolicies | ForEach-Object { Write-Error $_ }
    exit 1
}
