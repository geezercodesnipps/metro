function Register-AzMgmtGroupRp {
    <#
        In anticipation of updated SDKs, this function can be used to register RPs at the management group scope

        .Synopsis
        Register RPs at management group scope
        .Example
        Register-AzManagementGroupRp -MgmtGroupId "Pluto" -RPName "Microsoft.Security"
    #>

    [cmdletbinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [string] $MgmtGroupId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $RPName
    )
    begin {
        # Get Token
        $token = (Get-AzAccessToken).token
    }
    process {
    # ARM Request
    $ARMRequest = @{
        Uri = "https://management.azure.com/providers/Microsoft.Management/managementGroups/$($MgmtGroupId)/providers/$($RPName)/register?api-version=2021-04-01"
        Headers = @{
            Authorization = "Bearer $($token)"
            'Content-Type' = 'application/json'
        }
        Method = 'Post'
        Body = $body
        UseBasicParsing = $true
    }
    $RegisterRp = Invoke-WebRequest @ARMRequest
    Write-Output $RegisterRp.StatusCode
    }
}
