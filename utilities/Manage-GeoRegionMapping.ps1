#Requires -Version 5.1

<#
.SYNOPSIS
    Simple script to add/remove regions in geo_region_mapping array

.PARAMETER Action
    AddRegion or RemoveRegion

.PARAMETER VarsFilePath
    Path to vars.tfvars file

.PARAMETER GeoName
    Name of geo (EMEA, UAE)

.PARAMETER RegionName
    Name of region (northeurope, westeurope, etc.)

.PARAMETER RegionSubscriptionId  
    Subscription ID for the region

.PARAMETER Environment
    Environment name (dev, prod, etc.)
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('AddGeo', 'RemoveGeo', 'AddRegion', 'RemoveRegion')]
    [string]$Action,

    [Parameter(Mandatory = $true)]
    [string]$VarsFilePath,

    [Parameter(Mandatory = $true)]
    [string]$GeoName,

    [Parameter(Mandatory = $false)]
    [string]$RegionName,

    [Parameter(Mandatory = $false)]
    [string]$RegionSubscriptionId = "test-subscription-id",

    [Parameter(Mandatory = $false)]
    [string]$GeoPlatformSubscriptionId = "test-geo-platform-subscription-id",

    [Parameter(Mandatory = $false)]
    [string]$Environment = "dev"
)

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $(if($Level -eq "ERROR") {"Red"} elseif($Level -eq "WARNING") {"Yellow"} else {"Green"})
}

function Get-NextAvailableIPRange {
    param(
        [string]$Content,
        [string]$GeoName
    )
    
    Write-Log "Analyzing existing IP ranges in geo: $GeoName"
    
    # Extract all existing 10.x.x.x/22 ranges from the target geo
    $existingRanges = @()
    $lines = $Content -split "`r?`n"
    $inTargetGeo = $false
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        
        # Check if we're entering the target geo
        if ($line -match "geo_name\s*=\s*`"$GeoName`"") {
            $inTargetGeo = $true
            Write-Log "Found target geo '$GeoName' - analyzing IP ranges"
            continue
        }
        
        # Check if we're exiting the target geo
        if ($inTargetGeo -and $line -match "^\s*\}\s*$" -and $line -notmatch "network\s*=") {
            # This might be the geo's closing brace
            $bracketCount = 0
            # Check if this is really the geo closing by counting brackets backward
            for ($j = $i; $j -ge 0; $j--) {
                if ($lines[$j] -match "geo_name\s*=\s*`"$GeoName`"") {
                    break
                }
                foreach ($char in $lines[$j].ToCharArray()) {
                    if ($char -eq '{') { $bracketCount++ }
                    elseif ($char -eq '}') { $bracketCount-- }
                }
            }
            if ($bracketCount -eq 0) {
                $inTargetGeo = $false
                break
            }
        }
        
        # Look for address_space_network_hub within the target geo
        if ($inTargetGeo -and $line -match "address_space_network_hub\s*=\s*`"(10\.\d+\.\d+\.\d+/22)`"") {
            $range = $matches[1]
            $existingRanges += $range
            Write-Log "Found existing IP range: $range"
        }
    }
    
    # Parse existing ranges to find the next available /22 block
    $usedBlocks = @()
    foreach ($range in $existingRanges) {
        if ($range -match "10\.(\d+)\.(\d+)\.(\d+)/22") {
            $secondOctet = [int]$matches[1]
            $thirdOctet = [int]$matches[2]
            # Convert to a single number for easier comparison (second_octet * 256 + third_octet)
            $blockNumber = $secondOctet * 256 + $thirdOctet
            $usedBlocks += $blockNumber
        }
    }
    
    # Sort and find the next available block
    $usedBlocks = $usedBlocks | Sort-Object
    Write-Log "Used IP blocks: $($usedBlocks -join ', ')"
    
    # Start searching from 10.0.0.0/22 (block 0)
    $nextBlock = 0
    foreach ($usedBlock in $usedBlocks) {
        if ($nextBlock -eq $usedBlock) {
            $nextBlock += 4  # /22 networks are 4 apart (1024 addresses)
        } else {
            break
        }
    }
    
    # Convert block number back to IP
    $secondOctet = [int]($nextBlock / 256)
    $thirdOctet = $nextBlock % 256
    
    # Ensure we don't exceed valid IP ranges
    if ($secondOctet -gt 255) {
        throw "No more available IP ranges in 10.x.x.x space for geo $GeoName"
    }
    
    $baseNetwork = "10.$secondOctet.$thirdOctet.0"
    Write-Log "Next available IP block: $baseNetwork/22 (block number: $nextBlock)"
    
    # Generate all required subnets within the /22 block
    $ipRanges = @{
        "address_space_allocated" = @(
            "$baseNetwork/22",
            "172.32.0.0/12"  # Keep the private range constant
        )
        "address_space_network_hub" = "$baseNetwork/22"
        "address_space_gateway_subnet" = "$baseNetwork/26"          # First /26: .0-.63
        "address_space_azfw_subnet" = "10.$secondOctet.$thirdOctet.64/26"     # Second /26: .64-.127  
        "address_space_azfw_management_subnet" = "10.$secondOctet.$thirdOctet.128/26"  # Third /26: .128-.191
        "address_space_dns_inbound_subnet" = "10.$secondOctet.$thirdOctet.192/26"     # Fourth /26: .192-.255
        "address_space_dns_outbound_subnet" = "10.$secondOctet.$([int]($thirdOctet) + 1).0/26"  # Next block first /26
    }
    
    Write-Log "Generated IP ranges for new region:"
    Write-Log "  Network Hub: $($ipRanges.address_space_network_hub)"
    Write-Log "  Gateway: $($ipRanges.address_space_gateway_subnet)" 
    Write-Log "  Firewall: $($ipRanges.address_space_azfw_subnet)"
    Write-Log "  FW Management: $($ipRanges.address_space_azfw_management_subnet)"
    Write-Log "  DNS Inbound: $($ipRanges.address_space_dns_inbound_subnet)"
    Write-Log "  DNS Outbound: $($ipRanges.address_space_dns_outbound_subnet)"
    
    return $ipRanges
}

function Add-Geo {
    param([string]$Content)
    
    Write-Log "Adding new geo: $GeoName"
    
    # Check if geo already exists
    if ($Content -match "geo_name\s*=\s*`"$GeoName`"") {
        Write-Log "Geo $GeoName already exists. Skipping." -Level "WARNING"
        return $Content
    }
    
    # Validate that RegionName is provided for AddGeo
    if ([string]::IsNullOrEmpty($RegionName)) {
        throw "RegionName is required when adding a new geo"
    }
    
    # Determine geo platform location based on geo name and region
    $geoPlatformLocation = switch ($GeoName) {
        "EMEA" { 
            if ($RegionName -in @("northeurope", "westeurope")) { "westeurope" }
            elseif ($RegionName -in @("uksouth", "ukwest")) { "uksouth" }
            else { "westeurope" } # default for EMEA
        }
        "UAE" { 
            if ($RegionName -in @("uaenorth", "uaesouth")) { "uaenorth" }
            else { "uaenorth" } # default for UAE
        }
        default { 
            Write-Log "Unknown geo '$GeoName', using region '$RegionName' as platform location" -Level "WARNING"
            $RegionName 
        }
    }
    
    Write-Log "Using geo platform location: $geoPlatformLocation"
    
    # Get dynamic IP ranges for the first region in the new geo
    # Since this is a new geo, we'll start with block 0 for the first region
    $ipRanges = @{
        "address_space_allocated" = @(
            "10.0.0.0/22",
            "172.32.0.0/12"
        )
        "address_space_network_hub" = "10.0.0.0/22"
        "address_space_gateway_subnet" = "10.0.0.0/26"
        "address_space_azfw_subnet" = "10.0.0.64/26"
        "address_space_azfw_management_subnet" = "10.0.0.128/26"
        "address_space_dns_inbound_subnet" = "10.0.0.192/26"
        "address_space_dns_outbound_subnet" = "10.0.1.0/26"
    }
    
    # However, we should check if this IP range conflicts with existing geos
    $allExistingRanges = @()
    $lines = $Content -split "`r?`n"
    
    # Find all existing IP ranges across all geos
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match "address_space_network_hub\s*=\s*`"(10\.\d+\.\d+\.\d+/22)`"") {
            $range = $matches[1]
            $allExistingRanges += $range
            Write-Log "Found existing IP range across all geos: $range"
        }
    }
    
    # Find next available IP range across all geos
    $usedBlocks = @()
    foreach ($range in $allExistingRanges) {
        if ($range -match "10\.(\d+)\.(\d+)\.(\d+)/22") {
            $secondOctet = [int]$matches[1]
            $thirdOctet = [int]$matches[2]
            $blockNumber = $secondOctet * 256 + $thirdOctet
            $usedBlocks += $blockNumber
        }
    }
    
    # Sort and find the next available block
    $usedBlocks = $usedBlocks | Sort-Object
    Write-Log "Used IP blocks across all geos: $($usedBlocks -join ', ')"
    
    $nextBlock = 0
    foreach ($usedBlock in $usedBlocks) {
        if ($nextBlock -eq $usedBlock) {
            $nextBlock += 4  # /22 networks are 4 apart
        } else {
            break
        }
    }
    
    # Update IP ranges with the available block
    $secondOctet = [int]($nextBlock / 256)
    $thirdOctet = $nextBlock % 256
    $baseNetwork = "10.$secondOctet.$thirdOctet.0"
    
    Write-Log "Allocated IP block for new geo '$GeoName': $baseNetwork/22 (block number: $nextBlock)"
    
    $ipRanges = @{
        "address_space_allocated" = @(
            "$baseNetwork/22",
            "172.32.0.0/12"
        )
        "address_space_network_hub" = "$baseNetwork/22"
        "address_space_gateway_subnet" = "$baseNetwork/26"
        "address_space_azfw_subnet" = "10.$secondOctet.$thirdOctet.64/26"
        "address_space_azfw_management_subnet" = "10.$secondOctet.$thirdOctet.128/26"
        "address_space_dns_inbound_subnet" = "10.$secondOctet.$thirdOctet.192/26"
        "address_space_dns_outbound_subnet" = "10.$secondOctet.$([int]($thirdOctet) + 1).0/26"
    }
    
    # Create the new geo block with the first region
    $allocatedSpaceArray = $ipRanges.address_space_allocated | ForEach-Object { "`"$_`"" }
    $allocatedSpaceString = $allocatedSpaceArray -join ",`n                "
    
    $newGeoBlock = @"
  {
    geo_name                     = "$GeoName"
    geo_platform_subscription_id = "$GeoPlatformSubscriptionId" 
    geo_platform_location        = "$geoPlatformLocation"
    regions = [
      {
        azure_region_name = "$RegionName"
        environments = [
          {
            environment_name = "$Environment"
            network = {
              subscription_id = "$RegionSubscriptionId"
              dns_environment = "$Environment"
              address_space_allocated = [
                $allocatedSpaceString
              ]
              address_space_network_hub            = "$($ipRanges.address_space_network_hub)"
              address_space_gateway_subnet         = "$($ipRanges.address_space_gateway_subnet)"
              address_space_azfw_subnet            = "$($ipRanges.address_space_azfw_subnet)"
              address_space_azfw_management_subnet = "$($ipRanges.address_space_azfw_management_subnet)"
              address_space_dns_inbound_subnet     = "$($ipRanges.address_space_dns_inbound_subnet)"
              address_space_dns_outbound_subnet    = "$($ipRanges.address_space_dns_outbound_subnet)"
              ergw_sku                             = "Standard"
              azfw_sku                             = "Basic"
            }
          }
        ]
      }
    ]
  }
"@

    # Find the end of the geo_region_mapping array to insert the new geo
    $lines = $Content -split "`r?`n"
    $result = @()
    $lastGeoEndIndex = -1
    $inGeoArray = $false
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        
        # Check if we're entering the geo_region_mapping array
        if ($line -match "geo_region_mapping\s*=\s*\[") {
            $inGeoArray = $true
            Write-Log "Found geo_region_mapping array at line $($i + 1)"
        }
        
        # Look for existing geo blocks within the array
        if ($inGeoArray -and $line -match "geo_name\s*=") {
            Write-Log "Found existing geo at line $($i + 1): '$line'"
            
            # Find the opening brace for this geo (should be before this line)
            $geoStartIndex = -1
            for ($j = $i - 1; $j -ge 0; $j--) {
                if ($lines[$j] -match "^\s*\{\s*$") {
                    $geoStartIndex = $j
                    Write-Log "Found geo opening brace at line $($j + 1)"
                    break
                }
            }
            
            if ($geoStartIndex -ne -1) {
                # Use brace-matching to find the corresponding closing brace
                $braceLevel = 0
                $geoEndIndex = -1
                
                for ($k = $geoStartIndex; $k -lt $lines.Count; $k++) {
                    $currentLine = $lines[$k]
                    
                    # Count opening braces
                    $openBraces = ($currentLine | Select-String -Pattern "\{" -AllMatches).Matches.Count
                    $braceLevel += $openBraces
                    
                    # Count closing braces
                    $closeBraces = ($currentLine | Select-String -Pattern "\}" -AllMatches).Matches.Count
                    $braceLevel -= $closeBraces
                    
                    # When braceLevel returns to 0, we've found the matching closing brace
                    if ($braceLevel -eq 0 -and $k -gt $geoStartIndex) {
                        $geoEndIndex = $k
                        Write-Log "Found geo closing brace at line $($k + 1) using brace-matching"
                        break
                    }
                }
                
                if ($geoEndIndex -ne -1) {
                    $lastGeoEndIndex = $geoEndIndex
                    Write-Log "Updated last geo end to line $($geoEndIndex + 1)"
                }
            }
        }
        
        # Check if we're at the end of the geo_region_mapping array
        if ($inGeoArray -and $line -match "^\s*\]\s*$") {
            $inGeoArray = $false
            Write-Log "Found end of geo_region_mapping array at line $($i + 1)"
        }
    }
    
    # Build the result, inserting the new geo after the last existing geo
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $result += $lines[$i]
        
        # If this is the line after the last geo's closing brace, insert the new geo
        if ($i -eq $lastGeoEndIndex) {
            # Add comma to the previous closing brace
            $result[$result.Count - 1] = $result[$result.Count - 1] + ","
            
            # Add the new geo
            $result += $newGeoBlock -split "`r?`n"
            Write-Log "Inserted new geo after line $($lastGeoEndIndex + 1)"
        }
    }
    
    # If no existing geos were found (first geo), handle that case
    if ($lastGeoEndIndex -eq -1) {
        Write-Log "No existing geos found - this will be the first geo"
        $result = @()
        $inGeoArray = $false
        
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            
            if ($line -match "geo_region_mapping\s*=\s*\[") {
                $inGeoArray = $true
            }
            
            if ($inGeoArray -and $line -match "^\s*\]\s*$") {
                $result += $newGeoBlock -split "`r?`n"
                $inGeoArray = $false
            }
            
            $result += $line
        }
    }
    
    Write-Log "Successfully added geo: $GeoName with first region: $RegionName"
    return $result -join "`n"
}

function Remove-Geo {
    param([string]$Content)
    
    Write-Log "Removing geo: $GeoName"
    
    $lines = $Content -split "`r?`n"
    $result = @()
    $geoStartIndex = -1
    $geoEndIndex = -1
    $foundTargetGeo = $false
    
    # Find the target geo by geo_name
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        
        # Look for geo_name = "target_geo" anywhere in the file
        if ($line -match "geo_name") {
            Write-Log "DEBUG: Found geo_name line: '$line'"
        }
        if ($line -match "geo_name\s*=\s*`"$GeoName`"" -and -not $foundTargetGeo) {
            $foundTargetGeo = $true
            Write-Log "Found target geo '$GeoName' at line $($i + 1)"
            
            # Find the opening brace for this geo (should be before this line)
            for ($j = $i - 1; $j -ge 0; $j--) {
                if ($lines[$j] -match "^\s*\{\s*$") {
                    $geoStartIndex = $j
                    Write-Log "Found geo opening brace at line $($j + 1)"
                    break
                }
            }
            
            if ($geoStartIndex -eq -1) {
                throw "Could not find opening brace for geo $GeoName"
            }
            
            # Track braces to find the matching closing brace
            $geoBraceLevel = 1  # We start after the opening brace
            for ($k = $geoStartIndex + 1; $k -lt $lines.Count; $k++) {
                $currentLine = $lines[$k]
                
                # Count braces in this line
                $openBraces = ($currentLine.ToCharArray() | Where-Object { $_ -eq '{' }).Count
                $closeBraces = ($currentLine.ToCharArray() | Where-Object { $_ -eq '}' }).Count
                
                $geoBraceLevel += $openBraces - $closeBraces
                
                # When brace level reaches 0, we found the matching closing brace
                if ($geoBraceLevel -eq 0) {
                    $geoEndIndex = $k
                    Write-Log "Found geo closing brace at line $($k + 1)"
                    break
                }
            }
            
            if ($geoEndIndex -eq -1) {
                throw "Could not find closing brace for geo $GeoName"
            }
            
            break
        }
    }
    
    if (-not $foundTargetGeo) {
        Write-Log "Geo $GeoName not found" -Level "WARNING"
        return $Content
    }
    
    # Copy all lines except the geo block
    for ($i = 0; $i -lt $lines.Count; $i++) {
        # Skip the entire geo block (from opening brace to closing brace)
        if ($i -ge $geoStartIndex -and $i -le $geoEndIndex) {
            continue
        }
        
        $line = $lines[$i]
        
        # Handle comma cleanup: if the line before geo start had a comma and 
        # we're now at a closing bracket/brace, remove the comma
        if ($i -eq $geoStartIndex - 1) {
            # Check if the next non-geo line (after the geo block) is a closing bracket/brace
            $nextNonGeoIndex = $geoEndIndex + 1
            if ($nextNonGeoIndex -lt $lines.Count) {
                $nextLine = $lines[$nextNonGeoIndex]
                if ($nextLine -match "^\s*[\]\}]" -and $line -match ",\s*$") {
                    # Remove trailing comma since this was the last item before a closing bracket
                    $line = $line -replace ",\s*$", ""
                    Write-Log "Removed trailing comma from line $($i + 1)"
                }
            }
        }
        
        $result += $line
    }
    
    Write-Log "Successfully removed geo: $GeoName (removed lines $($geoStartIndex + 1)-$($geoEndIndex + 1))"
    return $result -join "`n"
}

function Add-Region {
    param([string]$Content)
    
    Write-Log "Adding region: $RegionName to geo: $GeoName"
    
    # Check if region already exists
    if ($Content -match "azure_region_name\s*=\s*`"$RegionName`"") {
        Write-Log "Region $RegionName already exists. Skipping." -Level "WARNING"
        return $Content
    }
    
    # Get dynamic IP ranges for the new region
    $ipRanges = Get-NextAvailableIPRange -Content $Content -GeoName $GeoName
    
    # Create the new region block with dynamic IP allocation
    $allocatedSpaceArray = $ipRanges.address_space_allocated | ForEach-Object { "`"$_`"" }
    $allocatedSpaceString = $allocatedSpaceArray -join ",`n                "
    
    $newRegionBlock = @"
      {
        azure_region_name = "$RegionName"
        environments = [
          {
            environment_name = "$Environment"
            network = {
              subscription_id = "$RegionSubscriptionId"
              dns_environment = "$Environment"
              address_space_allocated = [
                $allocatedSpaceString
              ]
              address_space_network_hub            = "$($ipRanges.address_space_network_hub)"
              address_space_gateway_subnet         = "$($ipRanges.address_space_gateway_subnet)"
              address_space_azfw_subnet            = "$($ipRanges.address_space_azfw_subnet)"
              address_space_azfw_management_subnet = "$($ipRanges.address_space_azfw_management_subnet)"
              address_space_dns_inbound_subnet     = "$($ipRanges.address_space_dns_inbound_subnet)"
              address_space_dns_outbound_subnet    = "$($ipRanges.address_space_dns_outbound_subnet)"
              ergw_sku                             = "Standard"
              azfw_sku                             = "Basic"
            }
          }
        ]
      }
"@

    $lines = $Content -split "`r?`n"
    $result = @()
    $lastRegionEndIndex = -1
    $inTargetGeo = $false
    
    # First, find all existing regions in the target geo using brace-matching
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        
        # Check if we're entering the target geo
        if ($line -match "geo_name\s*=\s*`"$GeoName`"") {
            $inTargetGeo = $true
            Write-Log "Found target geo '$GeoName' at line $($i + 1)"
        }
        
        # Look for existing region start patterns within the target geo
        if ($inTargetGeo -and $line -match "azure_region_name\s*=") {
            Write-Log "Found existing region at line $($i + 1): '$line'"
            
            # Find the opening brace for this region (should be before this line)
            $regionStartIndex = -1
            for ($j = $i - 1; $j -ge 0; $j--) {
                if ($lines[$j] -match "^\s*\{\s*$") {
                    $regionStartIndex = $j
                    Write-Log "Found region opening brace at line $($j + 1)"
                    break
                }
            }
            
            if ($regionStartIndex -ne -1) {
                # Use brace-matching to find the corresponding closing brace
                $braceLevel = 0
                $regionEndIndex = -1
                
                for ($k = $regionStartIndex; $k -lt $lines.Count; $k++) {
                    $currentLine = $lines[$k]
                    
                    # Count opening braces
                    $openBraces = ($currentLine | Select-String -Pattern "\{" -AllMatches).Matches.Count
                    $braceLevel += $openBraces
                    
                    # Count closing braces
                    $closeBraces = ($currentLine | Select-String -Pattern "\}" -AllMatches).Matches.Count
                    $braceLevel -= $closeBraces
                    
                    # When braceLevel returns to 0, we've found the matching closing brace
                    if ($braceLevel -eq 0 -and $k -gt $regionStartIndex) {
                        $regionEndIndex = $k
                        Write-Log "Found region closing brace at line $($k + 1) using brace-matching"
                        break
                    }
                }
                
                if ($regionEndIndex -ne -1) {
                    $lastRegionEndIndex = $regionEndIndex
                    Write-Log "Updated last region end to line $($regionEndIndex + 1)"
                }
            }
        }
        
        # Check if we're exiting the target geo (reached the geo's closing brace)
        if ($inTargetGeo -and $line -match "^\s*\}\s*$") {
            # This could be the geo's closing brace - we'll break here
            $inTargetGeo = $false
        }
    }
    
    # Now build the result, inserting the new region after the last existing region
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $result += $lines[$i]
        
        # If this is the line after the last region's closing brace, insert the new region
        if ($i -eq $lastRegionEndIndex) {
            # Add comma to the previous closing brace
            $result[$result.Count - 1] = $result[$result.Count - 1] + ","
            
            # Add the new region
            $result += $newRegionBlock -split "`r?`n"
            Write-Log "Inserted new region after line $($lastRegionEndIndex + 1)"
        }
    }
    
    # If no existing regions were found, we need to handle first region case
    if ($lastRegionEndIndex -eq -1) {
        Write-Log "No existing regions found - this will be the first region"
        # Use the simple approach for first region
        $result = @()
        $inTargetGeo = $false
        
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            
            if ($line -match "geo_name\s*=\s*`"$GeoName`"") {
                $inTargetGeo = $true
            }
            
            if ($inTargetGeo -and $line -match "^\s*\]\s*$") {
                $result += $newRegionBlock -split "`r?`n"
                $inTargetGeo = $false
            }
            
            $result += $line
        }
    }
    
    Write-Log "Successfully added region: $RegionName"
    return $result -join "`n"
}

function Remove-Region {
    param([string]$Content)
    
    Write-Log "Removing region: $RegionName from geo: $GeoName"
    
    $lines = $Content -split "`r?`n"
    $result = @()
    $regionStartIndex = -1
    $regionEndIndex = -1
    $foundTargetRegion = $false
    
    # Find the target region by azure_region_name (simplified approach)
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        
        # Look for azure_region_name = "target_region" anywhere in the file
        if ($line -match "azure_region_name") {
            Write-Log "DEBUG: Found azure_region_name line: '$line'"
        }
        if ($line -match "azure_region_name\s*=\s*`"$RegionName`"" -and -not $foundTargetRegion) {
            $foundTargetRegion = $true
            Write-Log "Found target region '$RegionName' at line $($i + 1)"
            
            # Find the opening brace for this region (should be before this line)
            for ($j = $i - 1; $j -ge 0; $j--) {
                if ($lines[$j] -match "^\s*\{\s*$") {
                    $regionStartIndex = $j
                    Write-Log "Found region opening brace at line $($j + 1)"
                    break
                }
            }
            
            if ($regionStartIndex -eq -1) {
                throw "Could not find opening brace for region $RegionName"
            }
            
            # Track braces to find the matching closing brace
            $regionBraceLevel = 1  # We start after the opening brace
            for ($k = $regionStartIndex + 1; $k -lt $lines.Count; $k++) {
                $currentLine = $lines[$k]
                
                # Count braces in this line
                $openBraces = ($currentLine.ToCharArray() | Where-Object { $_ -eq '{' }).Count
                $closeBraces = ($currentLine.ToCharArray() | Where-Object { $_ -eq '}' }).Count
                
                $regionBraceLevel += $openBraces - $closeBraces
                
                # When brace level reaches 0, we found the matching closing brace
                if ($regionBraceLevel -eq 0) {
                    $regionEndIndex = $k
                    Write-Log "Found region closing brace at line $($k + 1)"
                    break
                }
            }
            
            if ($regionEndIndex -eq -1) {
                throw "Could not find closing brace for region $RegionName"
            }
            
            break
        }
    }
    
    if (-not $foundTargetRegion) {
        Write-Log "Region $RegionName not found" -Level "WARNING"
        return $Content
    }
    
    # Copy all lines except the region block
    for ($i = 0; $i -lt $lines.Count; $i++) {
        # Skip the entire region block (from opening brace to closing brace)
        if ($i -ge $regionStartIndex -and $i -le $regionEndIndex) {
            continue
        }
        
        $line = $lines[$i]
        
        # Handle comma cleanup: if the line before region start had a comma and 
        # we're now at a closing bracket/brace, remove the comma
        if ($i -eq $regionStartIndex - 1) {
            # Check if the next non-region line (after the region block) is a closing bracket/brace
            $nextNonRegionIndex = $regionEndIndex + 1
            if ($nextNonRegionIndex -lt $lines.Count) {
                $nextLine = $lines[$nextNonRegionIndex]
                if ($nextLine -match "^\s*[\]\}]" -and $line -match ",\s*$") {
                    # Remove trailing comma since this was the last item before a closing bracket
                    $line = $line -replace ",\s*$", ""
                    Write-Log "Removed trailing comma from line $($i + 1)"
                }
            }
        }
        
        $result += $line
    }
    
    Write-Log "Successfully removed region: $RegionName (removed lines $($regionStartIndex + 1)-$($regionEndIndex + 1))"
    return $result -join "`n"
}

# Main execution
try {
    Write-Log "Starting operation: $Action"
    
    if (-not (Test-Path $VarsFilePath)) {
        throw "File not found: $VarsFilePath"
    }
    
    $content = Get-Content $VarsFilePath -Raw
    
    # Perform operation
    switch ($Action) {
        'AddGeo' { 
            $newContent = Add-Geo -Content $content 
        }
        'RemoveGeo' { 
            $newContent = Remove-Geo -Content $content 
        }
        'AddRegion' { 
            $newContent = Add-Region -Content $content 
        }
        'RemoveRegion' { 
            $newContent = Remove-Region -Content $content 
        }
    }
    
    # Save result
    $newContent | Set-Content $VarsFilePath -NoNewline
    Write-Log "Operation completed successfully"
    
    # Explicitly set exit code to 0 for successful completion
    exit 0
    
} catch {
    Write-Log "ERROR: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}
