# Test Prerequisites Script - Verify Azure CLI and Terraform detection
# This script tests the same logic used in the Azure DevOps pipeline

Write-Host "🔍 Testing prerequisites detection locally..."
Write-Host ""

# Check if running on self-hosted agent
if ($env:AGENT_NAME) {
  Write-Host "✅ Running on self-hosted agent: $($env:AGENT_NAME)"
} else {
  Write-Host "ℹ️ Running locally (not on agent)"
}
Write-Host ""

# Check Terraform installation
Write-Host "Testing Terraform detection..."
try {
  $terraformVersion = terraform version | Select-Object -First 1
  Write-Host "✅ Terraform found: $terraformVersion"
} catch {
  Write-Host "❌ Terraform not found"
  Write-Host "Please install Terraform manually"
  Write-Host "Download from: https://releases.hashicorp.com/terraform/"
}
Write-Host ""

# Check Azure CLI - NEW IMPROVED METHOD
Write-Host "Testing Azure CLI detection..."
try {
  $null = az --version 2>$null
  if ($LASTEXITCODE -eq 0) {
    $azVersionOutput = az --version | Select-Object -First 1
    Write-Host "✅ Azure CLI found: $azVersionOutput"
  } else {
    throw "Azure CLI command failed"
  }
} catch {
  Write-Host "❌ Azure CLI not found"
  Write-Host "Please install Azure CLI"
  Write-Host "Download from: https://aka.ms/installazurecliwindows"
}
Write-Host ""

Write-Host "🎉 Prerequisites test completed!"
Write-Host ""
Write-Host "If both Terraform and Azure CLI show ✅, your pipeline should work!"
