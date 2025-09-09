#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Targeted Management Group Cleanup for ADIA hierarchy

.DESCRIPTION
    Deletes management groups in the correct order based on the actual structure found
#>

param(
    [switch]$DryRun,
    [switch]$CleanZombieRoles = $true
)

function Write-Log {
    param([string]$Message, [string]$Level = "Info")
    $emoji = switch ($Level) {
        "Info" { "ℹ️" }
        "Warning" { "⚠️" }
        "Error" { "❌" }
        "Success" { "✅" }
        "Debug" { "🔍" }
    }
    Write-Host "$emoji $Message" -ForegroundColor $(
        switch ($Level) {
            "Info" { "White" }
            "Warning" { "Yellow" }
            "Error" { "Red" }
            "Success" { "Green" }
            "Debug" { "Cyan" }
        }
    )
}

function Find-ZombieRoleAssignments {
    param([string]$Scope)
    
    Write-Log "🔍 Scanning for zombie role assignments at scope: $Scope" -Level "Debug"
    
    try {
        $roleAssignments = Get-AzRoleAssignment -Scope $Scope -ErrorAction SilentlyContinue
        $zombieAssignments = @()
        
        foreach ($assignment in $roleAssignments) {
            # Check for zombie indicators: empty DisplayName, empty SignInName, or Unknown ObjectType
            if ([string]::IsNullOrEmpty($assignment.DisplayName) -or 
                [string]::IsNullOrEmpty($assignment.SignInName) -or
                $assignment.ObjectType -eq "Unknown") {
                
                Write-Log "  🧟 Found zombie assignment: $($assignment.RoleAssignmentId)" -Level "Warning"
                Write-Log "    Principal ID: $($assignment.ObjectId)" -Level "Warning"
                Write-Log "    Role: $($assignment.RoleDefinitionName)" -Level "Warning"
                Write-Log "    Object Type: $($assignment.ObjectType)" -Level "Warning"
                
                $zombieAssignments += $assignment
            }
        }
        
        return $zombieAssignments
    }
    catch {
        Write-Log "Error scanning scope '$Scope': $($_.Exception.Message)" -Level "Warning"
        return @()
    }
}

function Remove-ZombieRoleAssignment {
    param($Assignment)
    
    try {
        if ($DryRun) {
            Write-Log "DRY RUN: Would remove zombie role assignment: $($Assignment.RoleAssignmentId)" -Level "Warning"
            return $true
        }
        
        Write-Log "Removing zombie role assignment: $($Assignment.RoleAssignmentId)"
        Remove-AzRoleAssignment -ObjectId $Assignment.ObjectId -RoleDefinitionName $Assignment.RoleDefinitionName -Scope $Assignment.Scope -ErrorAction Stop
        Write-Log "Successfully removed zombie role assignment" -Level "Success"
        return $true
    }
    catch {
        Write-Log "Failed to remove zombie assignment: $($_.Exception.Message)" -Level "Error"
        # Try alternative removal method using RoleAssignmentId
        try {
            Remove-AzRoleAssignment -RoleAssignmentId $Assignment.RoleAssignmentId -ErrorAction Stop
            Write-Log "Successfully removed zombie role assignment (alternative method)" -Level "Success"
            return $true
        }
        catch {
            Write-Log "Alternative removal also failed: $($_.Exception.Message)" -Level "Error"
            return $false
        }
    }
}

function Get-AllManagementGroupsRecursive {
    param([string]$RootGroupName = "fsi37-adia")
    
    $allGroups = [System.Collections.ArrayList]::new()
    $visited = @{}
    
    function Get-GroupHierarchy {
        param([string]$GroupName, [int]$Level = 0)
        
        if ($visited.ContainsKey($GroupName)) {
            return
        }
        $visited[$GroupName] = $true
        
        try {
            $group = Get-AzManagementGroup -GroupName $GroupName -Expand -ErrorAction SilentlyContinue
            if (-not $group) {
                return
            }
            
            $childrenNames = @()
            if ($group.Children) {
                foreach ($child in $group.Children) {
                    if ($child.Type -eq "Microsoft.Management/managementGroups") {
                        $childrenNames += $child.Name
                        # Recursively process children first
                        Get-GroupHierarchy -GroupName $child.Name -Level ($Level + 1)
                    }
                }
            }
            
            # Create group info as a custom object
            $groupInfo = [PSCustomObject]@{
                Name = $group.Name
                DisplayName = $group.DisplayName
                Level = $Level
                Children = $childrenNames
                Id = $group.Id
            }
            
            [void]$allGroups.Add($groupInfo)
        } catch {
            Write-Log "Error getting group '$GroupName': $($_.Exception.Message)" -Level "Warning"
        }
    }
    
    Get-GroupHierarchy -GroupName $RootGroupName
    # Sort by level descending (deepest children first) to ensure proper deletion order
    return $allGroups | Sort-Object Level -Descending
}

function Remove-ManagementGroupForced {
    param([string]$GroupName, [string]$DisplayName, [string]$GroupId, [int]$Level = 0)
    
    try {
        # First, clean zombie role assignments at this management group scope
        if ($CleanZombieRoles) {
            Write-Log "Cleaning zombie role assignments for management group: $DisplayName"
            $zombies = Find-ZombieRoleAssignments -Scope $GroupId
            
            foreach ($zombie in $zombies) {
                Remove-ZombieRoleAssignment -Assignment $zombie
                Start-Sleep -Seconds 2
            }
        }
        
        # Check if exists
        $group = Get-AzManagementGroup -GroupName $GroupName -ErrorAction SilentlyContinue
        if (-not $group) {
            Write-Log "Management group '$DisplayName' ($GroupName) does not exist" -Level "Warning"
            return $true
        }
        
        if ($DryRun) {
            Write-Log "DRY RUN: Would delete '$DisplayName' ($GroupName) [Level $Level]" -Level "Warning"
            return $true
        }
        
        Write-Log "Attempting to delete management group: '$DisplayName' ($GroupName) [Level $Level]"
        
        # Multiple deletion attempts with increasing wait times
        $attempts = @(0, 5, 10, 20, 30)
        foreach ($wait in $attempts) {
            if ($wait -gt 0) {
                Write-Log "Waiting $wait seconds before retry..."
                Start-Sleep -Seconds $wait
            }
            
            try {
                Remove-AzManagementGroup -GroupName $GroupName -Confirm:$false
                Write-Log "Successfully deleted: '$DisplayName'" -Level "Success"
                return $true
            } catch {
                $errorMsg = $_.Exception.Message
                if ($errorMsg -like "*non-empty*" -or $errorMsg -like "*children*") {
                    Write-Log "Group '$DisplayName' still has children - attempt $($attempts.IndexOf($wait) + 1)/$($attempts.Count)" -Level "Warning"
                    
                    # Try to show what children are blocking deletion
                    try {
                        $groupDetail = Get-AzManagementGroup -GroupName $GroupName -Expand -ErrorAction SilentlyContinue
                        if ($groupDetail -and $groupDetail.Children) {
                            Write-Log "  Blocking children:" -Level "Warning"
                            $groupDetail.Children | ForEach-Object {
                                Write-Log "    - $($_.Name) ($($_.DisplayName)) [Type: $($_.Type)]" -Level "Warning"
                            }
                        }
                    } catch {
                        # Ignore errors when trying to show children
                    }
                    
                    if ($wait -eq $attempts[-1]) {
                        Write-Log "Final attempt failed for '$DisplayName': $errorMsg" -Level "Error"
                        return $false
                    }
                } else {
                    Write-Log "Unexpected error for '$DisplayName': $errorMsg" -Level "Error"
                    return $false
                }
            }
        }
        
    } catch {
        Write-Log "Failed to process '$DisplayName': $($_.Exception.Message)" -Level "Error"
        return $false
    }
    
    return $false
}

# Main execution
Write-Log "🎯 Targeted Management Group Cleanup + Zombie Role Assignment Cleaner" -Level "Success"
Write-Log "======================================================================"

$context = Get-AzContext
if (-not $context) {
    Write-Log "Not connected to Azure" -Level "Error"
    exit 1
}

Write-Log "Connected as: $($context.Account.Id)" -Level "Success"

# Step 1: Clean tenant-level zombie assignments first if enabled
if ($CleanZombieRoles) {
    Write-Log "🧟 Step 1: Scanning for tenant-level zombie role assignments..." -Level "Info"
    
    try {
        $allAssignments = Get-AzRoleAssignment -ErrorAction SilentlyContinue
        $zombieCount = 0
        
        foreach ($assignment in $allAssignments) {
            if ([string]::IsNullOrEmpty($assignment.DisplayName) -or 
                [string]::IsNullOrEmpty($assignment.SignInName) -or
                $assignment.ObjectType -eq "Unknown") {
                
                Write-Log "Found tenant-level zombie: $($assignment.RoleAssignmentId)" -Level "Warning"
                if (Remove-ZombieRoleAssignment -Assignment $assignment) {
                    $zombieCount++
                }
            }
        }
        
        if ($zombieCount -gt 0) {
            Write-Log "Cleaned $zombieCount tenant-level zombie role assignments" -Level "Success"
        } else {
            Write-Log "No tenant-level zombie role assignments found" -Level "Info"
        }
    }
    catch {
        Write-Log "Error scanning tenant-level assignments: $($_.Exception.Message)" -Level "Warning"
    }
    Write-Log ""
}

# Discover all management groups dynamically
Write-Log "🔍 Step 2: Discovering management group hierarchy..." -Level "Info"
$allGroups = Get-AllManagementGroupsRecursive -RootGroupName "fsi37-adia"

if (-not $allGroups -or $allGroups.Count -eq 0) {
    Write-Log "No management groups found or root group 'fsi37-adia' doesn't exist" -Level "Warning"
    exit 0
}

Write-Log "📋 DISCOVERED HIERARCHY (deletion order):" -Level "Warning"
foreach ($group in $allGroups) {
    $indent = "  " * $group.Level
    $childCount = $group.Children.Count
    Write-Log "$indent- $($group.DisplayName) ($($group.Name)) [Level $($group.Level), Children: $childCount]" -Level "Warning"
}
Write-Log "====================================" -Level "Warning"

if (-not $DryRun) {
    Write-Log "⚠️ WARNING: This will:" -Level "Warning"
    Write-Log "  • Delete all discovered ADIA management groups" -Level "Warning"
    if ($CleanZombieRoles) {
        Write-Log "  • Remove all zombie role assignments (fixes deployment conflicts)" -Level "Warning"
    }
    Write-Log "  • Clean up orphaned assignments that cause ARM template failures" -Level "Warning"
    Write-Log ""
    $confirm = Read-Host "Type 'DELETE' to confirm"
    if ($confirm -ne "DELETE") {
        Write-Log "Operation cancelled" -Level "Warning"
        exit 0
    }
}

$allSuccess = $true
foreach ($group in $allGroups) {
    $result = Remove-ManagementGroupForced -GroupName $group.Name -DisplayName $group.DisplayName -GroupId $group.Id -Level $group.Level
    if (-not $result) {
        $allSuccess = $false
    }
    Start-Sleep -Seconds 5  # Longer pause between deletions for propagation
}

if ($DryRun) {
    Write-Log "DRY RUN COMPLETED - No changes made" -Level "Success"
} elseif ($allSuccess) {
    Write-Log "ALL MANAGEMENT GROUPS AND ZOMBIE ASSIGNMENTS DELETED SUCCESSFULLY!" -Level "Success"
    Write-Log "🎯 Your next deployment should work without role assignment conflicts!" -Level "Success"
} else {
    Write-Log "Some deletions failed - check errors above" -Level "Warning"
}

Write-Log ""
Write-Log "💡 RECOMMENDATIONS TO PREVENT FUTURE ISSUES:" -Level "Info"
Write-Log "1. Update ARM templates to use unique role assignment names: guid(scope, principalId, roleId, utcNow())" -Level "Info"
Write-Log "2. Always run this cleanup before redeploying with the same management group name" -Level "Info"
Write-Log "3. Wait 10-15 minutes after cleanup before starting new deployments" -Level "Info"
Write-Log "4. Consider using different management group names for each deployment cycle" -Level "Info"

Write-Log "Cleanup completed" -Level "Success"
