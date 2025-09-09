#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Terraform cleanup script for removing temporary files and resetting state.

.DESCRIPTION
    This script helps clean up temporary Terraform files, reset state, and
    prepare the workspace for fresh deployments.

.PARAMETER Target
    What to clean: 'temp', 'state', 'all'

.PARAMETER Force
    Skip confirmation prompts

.EXAMPLE
    .\terraform-cleanup.ps1 -Target temp
    .\terraform-cleanup.ps1 -Target all -Force
#>

param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("temp", "state", "all")]
    [string]$Target = "temp",

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Write-Success { param($Message) Write-Host $Message -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host $Message -ForegroundColor Yellow }
function Write-Info { param($Message) Write-Host $Message -ForegroundColor Cyan }

Write-Info "🧹 Starting Terraform cleanup process..."

try {
    switch ($Target) {
        "temp" {
            Write-Info "Cleaning temporary files..."
            
            # Remove Terraform plan files
            Get-ChildItem -Path . -Recurse -Name "tfplan" -File | ForEach-Object {
                Remove-Item $_ -Force
                Write-Success "Removed: $_"
            }
            
            # Remove Terraform crash logs
            Get-ChildItem -Path . -Recurse -Name "crash.log" -File | ForEach-Object {
                Remove-Item $_ -Force
                Write-Success "Removed: $_"
            }
            
            # Remove .terraform directories
            Get-ChildItem -Path . -Recurse -Name ".terraform" -Directory | ForEach-Object {
                Remove-Item $_ -Recurse -Force
                Write-Success "Removed: $_"
            }
        }
        
        "state" {
            if (-not $Force) {
                $confirm = Read-Host "This will remove local Terraform state. Are you sure? (yes/no)"
                if ($confirm -ne "yes") {
                    Write-Info "State cleanup cancelled"
                    return
                }
            }
            
            Write-Warning "Removing Terraform state files..."
            
            # Remove state files
            Get-ChildItem -Path . -Recurse -Name "terraform.tfstate*" -File | ForEach-Object {
                Remove-Item $_ -Force
                Write-Success "Removed: $_"
            }
            
            # Remove lock files
            Get-ChildItem -Path . -Recurse -Name ".terraform.lock.hcl" -File | ForEach-Object {
                Remove-Item $_ -Force
                Write-Success "Removed: $_"
            }
        }
        
        "all" {
            if (-not $Force) {
                $confirm = Read-Host "This will remove ALL Terraform files including state. Are you sure? (yes/no)"
                if ($confirm -ne "yes") {
                    Write-Info "Full cleanup cancelled"
                    return
                }
            }
            
            Write-Warning "Performing full cleanup..."
            
            # Clean temp files
            & $PSScriptRoot\terraform-cleanup.ps1 -Target temp -Force
            
            # Clean state files  
            & $PSScriptRoot\terraform-cleanup.ps1 -Target state -Force
        }
    }
    
    Write-Success "✅ Terraform cleanup completed successfully!"
    
} catch {
    Write-Error "❌ Cleanup failed: $($_.Exception.Message)"
    exit 1
}
