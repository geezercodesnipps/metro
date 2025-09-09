#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Local Terraform deployment script for Metropolis infrastructure.

.DESCRIPTION
    This script provides a convenient way to deploy Terraform infrastructure locally
    with proper validation and error handling. It supports both platform and landing zone deployments.

.PARAMETER DeploymentType
    The type of deployment: 'platform' or 'landing-zone'

.PARAMETER Tenant
    The tenant configuration to use (Tenant001, Tenant002, etc.)

.PARAMETER Action
    The Terraform action to perform: 'plan', 'apply', or 'destroy'

.PARAMETER AutoApprove
    Skip interactive approval for apply and destroy operations

.PARAMETER WorkingDirectory
    Override the default working directory

.EXAMPLE
    .\deploy.ps1 -DeploymentType platform -Tenant Tenant001 -Action plan

.EXAMPLE
    .\deploy.ps1 -DeploymentType landing-zone -Tenant Tenant001 -Action apply -AutoApprove
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("platform", "landing-zone")]
    [string]$DeploymentType,

    [Parameter(Mandatory = $true)]
    [ValidateSet("Tenant001", "Tenant002")]
    [string]$Tenant,

    [Parameter(Mandatory = $true)]
    [ValidateSet("plan", "apply", "destroy")]
    [string]$Action,

    [Parameter(Mandatory = $false)]
    [switch]$AutoApprove,

    [Parameter(Mandatory = $false)]
    [string]$WorkingDirectory
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Color functions for better output
function Write-Success { param($Message) Write-Host $Message -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host $Message -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host $Message -ForegroundColor Red }
function Write-Info { param($Message) Write-Host $Message -ForegroundColor Cyan }

# Main execution
try {
    Write-Info "🚀 Starting Terraform deployment for Metropolis"
    Write-Info "Deployment Type: $DeploymentType"
    Write-Info "Tenant: $Tenant"
    Write-Info "Action: $Action"

    # Set working directory based on deployment type
    if (-not $WorkingDirectory) {
        if ($DeploymentType -eq "platform") {
            $WorkingDirectory = Join-Path $PSScriptRoot "infrastructure\platform"
        } else {
            $WorkingDirectory = Join-Path $PSScriptRoot "infrastructure\file_new_lz"
        }
    }

    # Set configuration paths
    $BackendConfig = Join-Path $PSScriptRoot "config\$Tenant\azurerm.tfbackend"
    $TfVarsFile = Join-Path $PSScriptRoot "config\$Tenant\vars.tfvars"

    Write-Info "Working Directory: $WorkingDirectory"
    Write-Info "Backend Config: $BackendConfig"
    Write-Info "Variables File: $TfVarsFile"

    # Validate paths exist
    if (-not (Test-Path $WorkingDirectory)) {
        throw "Working directory not found: $WorkingDirectory"
    }
    if (-not (Test-Path $BackendConfig)) {
        throw "Backend configuration not found: $BackendConfig"
    }
    if (-not (Test-Path $TfVarsFile)) {
        throw "Variables file not found: $TfVarsFile"
    }

    # Check if Terraform is installed
    try {
        $null = Get-Command terraform -ErrorAction Stop
        $terraformVersion = terraform version
        Write-Success "✅ Terraform is installed: $($terraformVersion -split "`n" | Select-Object -First 1)"
    }
    catch {
        Write-Error "❌ Terraform is not installed or not in PATH"
        Write-Info "💡 Install Terraform using: winget install Hashicorp.Terraform"
        exit 1
    }

    # Change to working directory
    Push-Location $WorkingDirectory

    # Step 1: Format check
    Write-Info "📋 Checking Terraform formatting..."
    $formatResult = terraform fmt -check -recursive
    if ($LASTEXITCODE -eq 0) {
        Write-Success "✅ Terraform format check passed"
    } else {
        Write-Warning "⚠️  Terraform format issues found. Running format fix..."
        terraform fmt -recursive
        Write-Success "✅ Terraform formatting fixed"
    }

    # Step 2: Initialize
    Write-Info "🔧 Initializing Terraform..."
    $backendConfigPath = Resolve-Path (Join-Path ".." ".." $BackendConfig.Substring($PSScriptRoot.Length + 1))
    terraform init -backend-config="$backendConfigPath"
    if ($LASTEXITCODE -ne 0) {
        throw "Terraform init failed"
    }
    Write-Success "✅ Terraform initialized successfully"

    # Step 3: Validate
    Write-Info "🔍 Validating Terraform configuration..."
    terraform validate
    if ($LASTEXITCODE -ne 0) {
        throw "Terraform validation failed"
    }
    Write-Success "✅ Terraform validation passed"

    # Step 4: Execute action
    $tfVarsPath = Resolve-Path (Join-Path ".." ".." $TfVarsFile.Substring($PSScriptRoot.Length + 1))
    
    switch ($Action) {
        "plan" {
            Write-Info "📖 Running Terraform plan..."
            terraform plan -var-file="$tfVarsPath" -out="tfplan"
            if ($LASTEXITCODE -ne 0) {
                throw "Terraform plan failed"
            }
            Write-Success "✅ Terraform plan completed successfully"
            Write-Info "💡 Plan saved to 'tfplan'. Run with -Action apply to execute changes."
        }
        
        "apply" {
            Write-Info "🚀 Running Terraform apply..."
            
            # Check if tfplan exists, if not create one
            if (-not (Test-Path "tfplan")) {
                Write-Info "📖 No existing plan found. Creating plan first..."
                terraform plan -var-file="$tfVarsPath" -out="tfplan"
                if ($LASTEXITCODE -ne 0) {
                    throw "Terraform plan failed"
                }
            }
            
            if ($AutoApprove) {
                terraform apply -auto-approve "tfplan"
            } else {
                terraform apply "tfplan"
            }
            
            if ($LASTEXITCODE -ne 0) {
                throw "Terraform apply failed"
            }
            Write-Success "✅ Terraform apply completed successfully"
            
            # Provide Azure Portal links
            Write-Info ""
            Write-Success "🎉 Deployment completed! Access your resources:"
            Write-Info "🌐 Resource Groups: https://portal.azure.com/#view/HubsExtension/BrowseResourceGroups"
            Write-Info "🏢 Management Groups: https://portal.azure.com/#view/Microsoft_Azure_ManagementGroups/ManagementGroupBrowseBlade"
            Write-Info "📋 Policy Assignments: https://portal.azure.com/#view/Microsoft_Azure_Policy/PolicyMenuBlade/~/Assignments"
            Write-Info "📊 Activity Log: https://portal.azure.com/#view/Microsoft_Azure_ActivityLog/ActivityLogBlade"
        }
        
        "destroy" {
            Write-Warning "⚠️  This will DESTROY all infrastructure managed by this Terraform configuration!"
            
            if (-not $AutoApprove) {
                $confirm = Read-Host "Are you sure you want to proceed? Type 'yes' to confirm"
                if ($confirm -ne "yes") {
                    Write-Info "❌ Destroy operation cancelled"
                    exit 0
                }
            }
            
            Write-Info "💥 Running Terraform destroy..."
            if ($AutoApprove) {
                terraform destroy -auto-approve -var-file="$tfVarsPath"
            } else {
                terraform destroy -var-file="$tfVarsPath"
            }
            
            if ($LASTEXITCODE -ne 0) {
                throw "Terraform destroy failed"
            }
            Write-Success "✅ Terraform destroy completed successfully"
        }
    }

} catch {
    Write-Error "❌ Error: $($_.Exception.Message)"
    exit 1
} finally {
    # Return to original directory
    Pop-Location
}

Write-Success "🎯 Terraform $Action operation completed successfully!"
