<#
.SYNOPSIS
    Validates and fixes role assignments for a principal in multiple Azure subscriptions based on input from a parameter file.
    Also checks for required resource providers and registers them if missing.

.DESCRIPTION
    This script checks if the specified or current Azure principal has the "Owner" role assigned in the subscriptions listed within a provided parameter file.
    If the role assignment is missing and the -FixPermissions switch is used, it assigns the "Owner" role to the principal in each subscription where it is missing.
    Additionally, it checks if key Azure resource providers are registered in the subscriptions, and registers them if they are not.

.PARAMETER ParameterFile
    The file path containing subscription IDs to be checked. This parameter is mandatory.

.PARAMETER PrincipalId
    The Azure principal's ID (user, service principal, or managed identity) whose role assignments are being checked. If not provided, the current Azure context's principal is used.

.PARAMETER FixPermissions
    A switch parameter. If provided, missing "Owner" role assignments are fixed by adding the "Owner" role to the principal in the relevant subscriptions.
#>
param (
    [parameter(Mandatory = $true)]
    [string]$ParameterFile,
    [parameter(Mandatory = $true)]
    [string]$ManagementGroupId,
    [parameter(Mandatory = $false)]
    [string]$PrincipalId,
    [switch]$FixPermissions
)

# Define required resource providers
$requiredProviders = @(
    'Microsoft.OperationsManagement',
    'Microsoft.OperationalInsights',
    'Microsoft.Network',
    'Microsoft.Security',
    'Microsoft.Insights',
    'Microsoft.PolicyInsights'
    'Microsoft.Compute/EncryptionAtHost'
)

# Function to check if required resource providers are registered in a subscription
function Test-ResourceProviders {
    param (
        [string]$subscriptionId
    )

    Write-Host "Checking resource provider registration in subscription $subscriptionId"

    # Switch to the target subscription context
    $null = Set-AzContext -SubscriptionId $subscriptionId

    # Get registered providers
    $registeredProviders = Get-AzResourceProvider | Where-Object { $_.RegistrationState -eq 'Registered' }

    # Check each provider or feature
    foreach ($provider in $requiredProviders) {
        $providerParts = $provider -split '/'
        $providerNamespace = $providerParts[0]

        # Check if provider is registered
        $providerExists = $registeredProviders | Where-Object { $_.ProviderNamespace -eq $providerNamespace }

        # Register provider if not registered
        if (-not $providerExists) {
            Write-Host "Registering provider $providerNamespace in subscription $subscriptionId"
            Register-AzResourceProvider -ProviderNamespace $providerNamespace
        }

        # Check for and register feature if present
        if ($providerParts.Count -gt 1) {
            $featureName = $providerParts[1]
            $registeredFeatures = $providerExists.ResourceTypes

            if (-not ($registeredFeatures | Where-Object { $_.ResourceTypeName -eq $featureName -and $_.RegistrationState -eq 'Registered' })) {
                Write-Host "Enabling feature $featureName for provider $providerNamespace"
                Register-AzProviderFeature -FeatureName $featureName -ProviderNamespace $providerNamespace
            }
        }
    }
}

# Function to extract subscription IDs from the parameter file
function Get-SubscriptionId {
    param (
        [string]$filePath
    )

    # Extract lines that contain 'subscriptionId' and are not commented out, then return unique GUIDs
    $subscriptionIds = Select-String -Path $filePath -Pattern 'subscriptionId' | ForEach-Object {
        $line = $_.Line.Trim()

        # Skip lines that start with '//'
        if ($line -notmatch '^\s*//') {
            # Match and return any GUIDs (assumed to be subscription IDs)
            if ($line -match '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}') {
                return $matches[0]
            }
        }
    }

    return $subscriptionIds | Sort-Object -Unique   # Return sorted and unique subscription IDs
}

# Function to get the principal ID of the current Azure context
function Get-AzOpsCurrentPrincipal {
    <#
        .SYNOPSIS
            Retrieves the object ID or client ID for the current Azure principal
        .DESCRIPTION
            This function retrieves the principal (user or managed identity) ID based on the current Azure context.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        $AzContext = (Get-AzContext)   # Azure context, defaults to current context if not provided
    )

    process {
        # Determine principal based on the type of Azure account (User or Managed Service)
        switch ($AzContext.Account.Type) {
            'User' {
                # For a user, retrieve information from Microsoft Graph API
                $restMethodResult = Invoke-AzRestMethod -Uri https://graph.microsoft.com/v1.0/me -ErrorAction Stop
                if ($restMethodResult) {
                    $principalObject = $restMethodResult.Content | ConvertFrom-Json -ErrorAction Stop
                }
            }
            'ManagedService' {
                # For managed service identity, retrieve application ID via the IMDS service
                $restMethodResult = Invoke-RestMethod -Uri "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2021-02-01&resource=https%3A%2F%2Fmanagement.azure.com%2F" -Headers @{ Metadata = $true } -ErrorAction Stop
                if ($restMethodResult.client_id) {
                    # Get the service principal object by its application ID
                    $principalObject = Get-AzADServicePrincipal -ApplicationId $restMethodResult.client_id -ErrorAction Stop
                }
            }
            default {
                # Fallback to get service principal by account ID
                $principalObject = Get-AzADServicePrincipal -ApplicationId $AzContext.Account.Id -ErrorAction Stop
            }
        }
        return $principalObject   # Return the principal object
    }
}

# If no PrincipalId is provided, retrieve the current Azure context principal ID
if (-not $PrincipalId) {
    $PrincipalId = (Get-AzOpsCurrentPrincipal).Id
}

# Retrieve subscription IDs from the provided parameter file
$platformSubscriptions = Get-SubscriptionId -filePath $ParameterFile

# Loop through each subscription and check role assignments and resource provider registration
foreach ($sub in $platformSubscriptions) {
    # Check if the principal has the "Owner" role assigned for the subscription
    Write-Host "Checking role assignment for principal id $PrincipalId in subscription $sub"
    $roleAssignment = Get-AzRoleAssignment -ObjectId $PrincipalId -Scope "/subscriptions/$sub" -ErrorAction SilentlyContinue | Where-Object { $_.RoleDefinitionId -eq '8e3af657-a8ff-443c-a75c-2fe8c4bcb635' }

    if (-not $roleAssignment ) {
        # Error if the role assignment doesn't exist
        Write-Error "Role assignment does not exist for principal id $PrincipalId in subscription $sub"

        if ($FixPermissions) {
            # If FixPermissions switch is enabled, assign the "Owner" role to the principal
            Write-Host "Fixing permissions for principal id $PrincipalId in subscription $sub"
            New-AzRoleAssignment -ObjectId $PrincipalId -RoleDefinitionName 'Owner' -Scope "/subscriptions/$sub"
        }
    }
    else {
        # Check and register missing resource providers
        Test-ResourceProviders -SubscriptionId $sub
    }
}

# Check for owner permissions in the intermediate management group access
$MgPermissions = Get-AzRoleAssignment -ObjectId $PrincipalId -Scope "/providers/Microsoft.Management/managementGroups/$ManagementGroupId" -ErrorAction SilentlyContinue | Where-Object { $_.RoleDefinitionId -eq '8e3af657-a8ff-443c-a75c-2fe8c4bcb635' }
if (-not $MgPermissions) {
    Write-Error "Role assignment does not exist for principal id $PrincipalId in intermediate root management group $ManagementGroupId"
} else {
    foreach ($role in $MgPermissions) {
        if (-not [string]::IsNullOrEmpty($role.Condition)) {
            Write-Error "Role assignment for $PrincipalId at intermediate management group $ManagementGroupId has conditions, which is not supported. Remove conditions and retry again."
        }
    }
}
