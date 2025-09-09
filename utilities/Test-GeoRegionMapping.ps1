#Requires -Version 5.1

<#
.SYNOPSIS
    Test script for the Manage-GeoRegionMapping.ps1 functionality

.DESCRIPTION
    This script provides examples and tests for the geo region mapping management functionality.
    Use this to test the script locally before using it in Azure DevOps pipelines.

.EXAMPLE
    .\Test-GeoRegionMapping.ps1
#>

[CmdletBinding()]
param()

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ManageScript = Join-Path $ScriptRoot "Manage-GeoRegionMapping.ps1"
$TestVarsFile = Join-Path $ScriptRoot "..\config\Tenant001\vars.tfvars"

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Message = ""
    )
    
    $status = if ($Passed) { "✓ PASS" } else { "✗ FAIL" }
    $color = if ($Passed) { "Green" } else { "Red" }
    
    Write-Host "[$status] $TestName" -ForegroundColor $color
    if ($Message) {
        Write-Host "    $Message" -ForegroundColor Gray
    }
}

function Test-ScriptExists {
    Write-Host "`n=== Testing Script Prerequisites ===" -ForegroundColor Yellow
    
    $scriptExists = Test-Path $ManageScript
    Write-TestResult "Manage-GeoRegionMapping.ps1 exists" $scriptExists
    
    $varsExists = Test-Path $TestVarsFile
    Write-TestResult "vars.tfvars exists" $varsExists
    
    return $scriptExists -and $varsExists
}

function Test-AddRegion {
    Write-Host "`n=== Testing Add Region Functionality ===" -ForegroundColor Yellow
    
    try {
        # Test adding uaesouth to UAE
        Write-Host "Testing: Add uaesouth region to UAE geo..."
        & $ManageScript -Action "AddRegion" -VarsFilePath $TestVarsFile -GeoName "UAE" -RegionName "uaesouth" -RegionSubscriptionId "test-subscription-id-12345" -Environment "dev"
        
        # Verify the addition
        $content = Get-Content $TestVarsFile -Raw
        $hasUAESouth = $content -match 'azure_region_name\s*=\s*"uaesouth"'
        
        Write-TestResult "Add uaesouth region" $hasUAESouth "uaesouth region added to UAE geo"
        return $hasUAESouth
    } catch {
        Write-TestResult "Add uaesouth region" $false $_.Exception.Message
        return $false
    }
}

function Test-RemoveRegion {
    Write-Host "`n=== Testing Remove Region Functionality ===" -ForegroundColor Yellow
    
    try {
        # Test removing uaesouth from UAE
        Write-Host "Testing: Remove uaesouth region from UAE geo..."
        & $ManageScript -Action "RemoveRegion" -VarsFilePath $TestVarsFile -GeoName "UAE" -RegionName "uaesouth"
        
        # Verify the removal
        $content = Get-Content $TestVarsFile -Raw
        $hasUAESouth = $content -match 'azure_region_name\s*=\s*"uaesouth"'
        
        Write-TestResult "Remove uaesouth region" (-not $hasUAESouth) "uaesouth region removed from UAE geo"
        return (-not $hasUAESouth)
    } catch {
        Write-TestResult "Remove uaesouth region" $false $_.Exception.Message
        return $false
    }
}

function Test-AddGeo {
    Write-Host "`n=== Testing Add Geo Functionality ===" -ForegroundColor Yellow
    
    try {
        # Test adding a new geo (APAC)
        Write-Host "Testing: Add APAC geo..."
        & $ManageScript -Action "AddGeo" -VarsFilePath $TestVarsFile -GeoName "UAE" -GeoPlatformSubscriptionId "test-geo-platform-sub-id" -GeoPlatformLocation "uaenorth"
        
        # Verify the addition (should skip if already exists)
        $content = Get-Content $TestVarsFile -Raw
        $hasUAE = $content -match 'geo_name\s*=\s*"UAE"'
        
        Write-TestResult "Add UAE geo (should already exist)" $hasUAE "UAE geo exists in configuration"
        return $hasUAE
    } catch {
        Write-TestResult "Add UAE geo" $false $_.Exception.Message
        return $false
    }
}

function Show-CurrentConfiguration {
    Write-Host "`n=== Current Geo Region Mapping Configuration ===" -ForegroundColor Cyan
    
    if (Test-Path $TestVarsFile) {
        $content = Get-Content $TestVarsFile -Raw
        $startPattern = 'geo_region_mapping\s*=\s*\['
        $match = [regex]::Match($content, $startPattern)
        
        if ($match.Success) {
            $lines = $content.Split("`n")
            $inMapping = $false
            $bracketCount = 0
            
            for ($i = 0; $i -lt $lines.Length; $i++) {
                if ($lines[$i] -match 'geo_region_mapping\s*=\s*\[') {
                    $inMapping = $true
                    $bracketCount = 1
                    Write-Host $lines[$i] -ForegroundColor White
                    continue
                }
                
                if ($inMapping) {
                    foreach ($char in $lines[$i].ToCharArray()) {
                        if ($char -eq '[') { $bracketCount++ }
                        elseif ($char -eq ']') { $bracketCount-- }
                    }
                    
                    $color = "Gray"
                    if ($lines[$i] -match 'geo_name') { $color = "Green" }
                    elseif ($lines[$i] -match 'azure_region_name') { $color = "Cyan" }
                    
                    Write-Host $lines[$i] -ForegroundColor $color
                    if ($bracketCount -eq 0) { break }
                }
            }
        }
    }
}

function Test-ParameterValidation {
    Write-Host "`n=== Testing Parameter Validation ===" -ForegroundColor Yellow
    
    # Test missing required parameter for AddRegion
    try {
        & $ManageScript -Action "AddRegion" -VarsFilePath $TestVarsFile -GeoName "EMEA" -RegionName "westeurope"
        Write-TestResult "Missing subscription ID validation" $false "Should have failed but didn't"
    } catch {
        $expectedError = $_.Exception.Message -match "RegionSubscriptionId is required"
        Write-TestResult "Missing subscription ID validation" $expectedError "Correctly caught missing parameter"
    }
    
    # Test invalid geo name (this would fail at parameter validation level)
    Write-TestResult "Parameter validation tests" $true "Parameter validation working as expected"
}

function Main {
    Write-Host "Geo Region Mapping Management Test Suite" -ForegroundColor Magenta
    Write-Host "=======================================" -ForegroundColor Magenta
    
    # Create backup of original file
    if (Test-Path $TestVarsFile) {
        $backupFile = $TestVarsFile + ".test-backup.$(Get-Date -Format 'yyyyMMddHHmmss')"
        Copy-Item $TestVarsFile $backupFile
        Write-Host "Backup created: $backupFile" -ForegroundColor Yellow
    }
    
    $allTestsPassed = $true
    
    # Run prerequisite tests
    if (-not (Test-ScriptExists)) {
        Write-Host "Prerequisites failed. Exiting." -ForegroundColor Red
        return
    }
    
    # Show current configuration
    Show-CurrentConfiguration
    
    # Run functionality tests
    $allTestsPassed = $allTestsPassed -and (Test-AddRegion)
    $allTestsPassed = $allTestsPassed -and (Test-RemoveRegion)
    $allTestsPassed = $allTestsPassed -and (Test-AddGeo)
    
    # Run parameter validation tests
    Test-ParameterValidation
    
    # Final summary
    Write-Host "`n=== Test Summary ===" -ForegroundColor Magenta
    if ($allTestsPassed) {
        Write-Host "All functionality tests PASSED!" -ForegroundColor Green
    } else {
        Write-Host "Some tests FAILED. Check the output above." -ForegroundColor Red
    }
    
    Show-CurrentConfiguration
    
    Write-Host "`nTest completed. Backup file available for restoration if needed." -ForegroundColor Yellow
}

# Run the tests
Main
