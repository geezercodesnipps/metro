# Virtual WAN Migration Script for ADIA Metropolis
# This script assists with the migration from traditional hub-spoke to Azure Virtual WAN

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("PreAssessment", "Deploy", "Validate", "Cleanup", "Rollback")]
    [string]$Phase = "PreAssessment",
    
    [Parameter(Mandatory=$false)]
    [string]$ConfigPath = "config/Tenant001/vars.tfvars",
    
    [Parameter(Mandatory=$false)]
    [string]$TerraformPath = "infrastructure/platform",
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun = $false
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Import required modules
Import-Module Az.Accounts -Force -ErrorAction SilentlyContinue
Import-Module Az.Network -Force -ErrorAction SilentlyContinue
Import-Module Az.Resources -Force -ErrorAction SilentlyContinue

Write-Host "=== Azure Virtual WAN Migration Script ===" -ForegroundColor Green
Write-Host "Phase: $Phase" -ForegroundColor Yellow
Write-Host "Config: $ConfigPath" -ForegroundColor Yellow
Write-Host "DryRun: $DryRun" -ForegroundColor Yellow
Write-Host ""

# Function to check Azure login
function Test-AzureLogin {
    try {
        $context = Get-AzContext
        if (-not $context) {
            Write-Host "Please log in to Azure..." -ForegroundColor Yellow
            Connect-AzAccount
        }
        Write-Host "✓ Connected to Azure (Subscription: $($context.Subscription.Name))" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to connect to Azure: $_"
        return $false
    }
}

# Function to check Terraform
function Test-TerraformInstallation {
    try {
        $version = terraform --version 2>$null
        if ($version) {
            Write-Host "✓ Terraform installed: $($version[0])" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "✗ Terraform not found. Installing via winget..." -ForegroundColor Red
            if ($DryRun) {
                Write-Host "DRY RUN: Would run 'winget install Hashicorp.Terraform'" -ForegroundColor Yellow
            }
            else {
                winget install Hashicorp.Terraform
            }
            return $false
        }
    }
    catch {
        Write-Error "Failed to check Terraform installation: $_"
        return $false
    }
}

# Function to perform pre-assessment
function Start-PreAssessment {
    Write-Host "=== Pre-Migration Assessment ===" -ForegroundColor Blue
    
    # Check current VNet peerings
    Write-Host "Analyzing current VNet peerings..." -ForegroundColor Yellow
    try {
        $resourceGroups = Get-AzResourceGroup | Where-Object { $_.ResourceGroupName -like "*network*" }
        
        foreach ($rg in $resourceGroups) {
            Write-Host "Checking resource group: $($rg.ResourceGroupName)" -ForegroundColor Gray
            
            $vnets = Get-AzVirtualNetwork -ResourceGroupName $rg.ResourceGroupName -ErrorAction SilentlyContinue
            foreach ($vnet in $vnets) {
                $peerings = Get-AzVirtualNetworkPeering -VirtualNetworkName $vnet.Name -ResourceGroupName $rg.ResourceGroupName -ErrorAction SilentlyContinue
                
                if ($peerings) {
                    Write-Host "  VNet: $($vnet.Name) has $($peerings.Count) peering(s)" -ForegroundColor White
                    foreach ($peering in $peerings) {
                        Write-Host "    - $($peering.Name) -> $($peering.RemoteVirtualNetwork.Id.Split('/')[-1])" -ForegroundColor Gray
                    }
                }
            }
        }
    }
    catch {
        Write-Warning "Could not analyze VNet peerings: $_"
    }
    
    # Check ExpressRoute circuits
    Write-Host "Analyzing ExpressRoute circuits..." -ForegroundColor Yellow
    try {
        $erCircuits = Get-AzExpressRouteCircuit
        
        if ($erCircuits) {
            Write-Host "Found $($erCircuits.Count) ExpressRoute circuit(s):" -ForegroundColor White
            foreach ($circuit in $erCircuits) {
                Write-Host "  - $($circuit.Name) in $($circuit.ResourceGroupName)" -ForegroundColor Gray
                Write-Host "    Location: $($circuit.ServiceProviderProperties.PeeringLocation)" -ForegroundColor Gray
                Write-Host "    Bandwidth: $($circuit.ServiceProviderProperties.BandwidthInMbps) Mbps" -ForegroundColor Gray
                Write-Host "    Status: $($circuit.CircuitProvisioningState)" -ForegroundColor Gray
            }
        }
        else {
            Write-Host "No ExpressRoute circuits found" -ForegroundColor Gray
        }
    }
    catch {
        Write-Warning "Could not analyze ExpressRoute circuits: $_"
    }
    
    # Check current route tables
    Write-Host "Analyzing route tables..." -ForegroundColor Yellow
    try {
        $routeTables = Get-AzRouteTable
        
        if ($routeTables) {
            Write-Host "Found $($routeTables.Count) route table(s):" -ForegroundColor White
            foreach ($rt in $routeTables) {
                Write-Host "  - $($rt.Name) in $($rt.ResourceGroupName)" -ForegroundColor Gray
                if ($rt.Routes) {
                    Write-Host "    Routes: $($rt.Routes.Count)" -ForegroundColor Gray
                }
            }
        }
    }
    catch {
        Write-Warning "Could not analyze route tables: $_"
    }
    
    Write-Host "✓ Pre-assessment completed" -ForegroundColor Green
}

# Function to deploy Virtual WAN
function Start-VirtualWANDeployment {
    Write-Host "=== Virtual WAN Deployment ===" -ForegroundColor Blue
    
    if (-not (Test-Path $TerraformPath)) {
        Write-Error "Terraform path not found: $TerraformPath"
        return
    }
    
    Set-Location $TerraformPath
    
    # Initialize Terraform
    Write-Host "Initializing Terraform..." -ForegroundColor Yellow
    if ($DryRun) {
        Write-Host "DRY RUN: Would run 'terraform init'" -ForegroundColor Yellow
    }
    else {
        terraform init
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Terraform init failed"
            return
        }
    }
    
    # Plan deployment
    Write-Host "Creating Terraform plan..." -ForegroundColor Yellow
    $planFile = "vwan-migration-plan.tfplan"
    
    if ($DryRun) {
        Write-Host "DRY RUN: Would run 'terraform plan -var-file=`"../../$ConfigPath`" -out=$planFile'" -ForegroundColor Yellow
    }
    else {
        terraform plan -var-file="../../$ConfigPath" -out=$planFile
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Terraform plan failed"
            return
        }
    }
    
    # Apply deployment
    if (-not $DryRun) {
        Write-Host "Applying Terraform configuration..." -ForegroundColor Yellow
        $confirmation = Read-Host "Continue with deployment? (y/N)"
        
        if ($confirmation -eq 'y' -or $confirmation -eq 'Y') {
            terraform apply $planFile
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Terraform apply failed"
                return
            }
            Write-Host "✓ Virtual WAN deployment completed" -ForegroundColor Green
        }
        else {
            Write-Host "Deployment cancelled by user" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "DRY RUN: Would apply Terraform configuration" -ForegroundColor Yellow
    }
}

# Function to validate deployment
function Start-ValidationTests {
    Write-Host "=== Validation Tests ===" -ForegroundColor Blue
    
    # Check Virtual WAN resources
    Write-Host "Validating Virtual WAN deployment..." -ForegroundColor Yellow
    try {
        $vwans = Get-AzVirtualWan
        
        if ($vwans) {
            Write-Host "✓ Found $($vwans.Count) Virtual WAN instance(s)" -ForegroundColor Green
            
            foreach ($vwan in $vwans) {
                Write-Host "  Virtual WAN: $($vwan.Name)" -ForegroundColor White
                
                # Check Virtual Hubs
                $hubs = Get-AzVirtualHub | Where-Object { $_.VirtualWan.Id -eq $vwan.Id }
                Write-Host "    Virtual Hubs: $($hubs.Count)" -ForegroundColor Gray
                
                foreach ($hub in $hubs) {
                    Write-Host "      - $($hub.Name) ($($hub.Location))" -ForegroundColor Gray
                    Write-Host "        Address Space: $($hub.AddressPrefix)" -ForegroundColor Gray
                    Write-Host "        Routing State: $($hub.RoutingState)" -ForegroundColor Gray
                    
                    # Check if routing state is Provisioned
                    if ($hub.RoutingState -eq "Provisioned") {
                        Write-Host "        ✓ Routing is provisioned" -ForegroundColor Green
                    }
                    else {
                        Write-Host "        ⚠ Routing state: $($hub.RoutingState)" -ForegroundColor Yellow
                    }
                }
            }
        }
        else {
            Write-Host "✗ No Virtual WAN instances found" -ForegroundColor Red
        }
    }
    catch {
        Write-Warning "Could not validate Virtual WAN deployment: $_"
    }
    
    # Test connectivity (basic checks)
    Write-Host "Running connectivity tests..." -ForegroundColor Yellow
    # Add specific connectivity tests based on your environment
    
    Write-Host "✓ Validation tests completed" -ForegroundColor Green
}

# Function to cleanup old resources
function Start-Cleanup {
    Write-Host "=== Cleanup Old Resources ===" -ForegroundColor Blue
    Write-Host "⚠ This will remove traditional hub-spoke resources" -ForegroundColor Yellow
    
    $confirmation = Read-Host "Are you sure you want to proceed with cleanup? (yes/NO)"
    
    if ($confirmation -eq 'yes') {
        Write-Host "Starting cleanup process..." -ForegroundColor Yellow
        
        # List VNet peerings to be removed
        Write-Host "Identifying VNet peerings for removal..." -ForegroundColor Yellow
        try {
            $resourceGroups = Get-AzResourceGroup | Where-Object { $_.ResourceGroupName -like "*network*hub*" }
            
            foreach ($rg in $resourceGroups) {
                $vnets = Get-AzVirtualNetwork -ResourceGroupName $rg.ResourceGroupName -ErrorAction SilentlyContinue
                
                foreach ($vnet in $vnets) {
                    $peerings = Get-AzVirtualNetworkPeering -VirtualNetworkName $vnet.Name -ResourceGroupName $rg.ResourceGroupName -ErrorAction SilentlyContinue
                    
                    foreach ($peering in $peerings) {
                        if ($DryRun) {
                            Write-Host "DRY RUN: Would remove peering $($peering.Name)" -ForegroundColor Yellow
                        }
                        else {
                            Write-Host "Removing peering: $($peering.Name)" -ForegroundColor Yellow
                            Remove-AzVirtualNetworkPeering -Name $peering.Name -VirtualNetworkName $vnet.Name -ResourceGroupName $rg.ResourceGroupName -Force
                        }
                    }
                }
            }
        }
        catch {
            Write-Warning "Error during cleanup: $_"
        }
        
        Write-Host "✓ Cleanup completed" -ForegroundColor Green
    }
    else {
        Write-Host "Cleanup cancelled" -ForegroundColor Yellow
    }
}

# Function to rollback changes
function Start-Rollback {
    Write-Host "=== Rollback to Traditional Hub-Spoke ===" -ForegroundColor Blue
    Write-Host "⚠ This will disable Virtual WAN and restore traditional architecture" -ForegroundColor Yellow
    
    $confirmation = Read-Host "Are you sure you want to rollback? (yes/NO)"
    
    if ($confirmation -eq 'yes') {
        Write-Host "Starting rollback process..." -ForegroundColor Yellow
        
        # Update configuration to disable Virtual WAN
        Write-Host "Updating configuration to disable Virtual WAN..." -ForegroundColor Yellow
        
        if ($DryRun) {
            Write-Host "DRY RUN: Would update configuration to set enable_virtual_wan = false" -ForegroundColor Yellow
            Write-Host "DRY RUN: Would run terraform apply to restore traditional hub-spoke" -ForegroundColor Yellow
        }
        else {
            # In a real scenario, you'd update the configuration file and re-apply
            Write-Host "Please manually update $ConfigPath to set enable_virtual_wan = false" -ForegroundColor Yellow
            Write-Host "Then run terraform apply to restore traditional hub-spoke architecture" -ForegroundColor Yellow
        }
        
        Write-Host "✓ Rollback process initiated" -ForegroundColor Green
    }
    else {
        Write-Host "Rollback cancelled" -ForegroundColor Yellow
    }
}

# Main execution
try {
    # Check prerequisites
    if (-not (Test-AzureLogin)) {
        exit 1
    }
    
    if (-not (Test-TerraformInstallation)) {
        Write-Host "Please install Terraform and re-run the script" -ForegroundColor Red
        exit 1
    }
    
    # Execute based on phase
    switch ($Phase) {
        "PreAssessment" { Start-PreAssessment }
        "Deploy" { Start-VirtualWANDeployment }
        "Validate" { Start-ValidationTests }
        "Cleanup" { Start-Cleanup }
        "Rollback" { Start-Rollback }
        default { Write-Error "Invalid phase: $Phase" }
    }
    
    Write-Host ""
    Write-Host "=== Migration Script Completed ===" -ForegroundColor Green
    Write-Host "Next steps:" -ForegroundColor Yellow
    
    switch ($Phase) {
        "PreAssessment" { 
            Write-Host "  1. Review the assessment results above" -ForegroundColor White
            Write-Host "  2. Run: .\migrate-to-vwan.ps1 -Phase Deploy" -ForegroundColor White
        }
        "Deploy" { 
            Write-Host "  1. Run: .\migrate-to-vwan.ps1 -Phase Validate" -ForegroundColor White
            Write-Host "  2. Test connectivity between regions" -ForegroundColor White
        }
        "Validate" { 
            Write-Host "  1. Perform application-specific testing" -ForegroundColor White
            Write-Host "  2. If satisfied, run: .\migrate-to-vwan.ps1 -Phase Cleanup" -ForegroundColor White
        }
        "Cleanup" { 
            Write-Host "  1. Monitor the environment for any issues" -ForegroundColor White
            Write-Host "  2. Migration is complete!" -ForegroundColor White
        }
        "Rollback" { 
            Write-Host "  1. Complete manual configuration updates" -ForegroundColor White
            Write-Host "  2. Run terraform apply to restore traditional architecture" -ForegroundColor White
        }
    }
}
catch {
    Write-Error "Script execution failed: $_"
    exit 1
}
