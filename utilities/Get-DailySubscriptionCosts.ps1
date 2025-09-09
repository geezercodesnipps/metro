# Get Daily Subscription Costs Script
# Loops through all subscriptions and retrieves the total running cost for the current day

param(
    [string]$OutputFormat = "Table", # Table, CSV, JSON
    [string]$OutputPath = $null,
    [switch]$IncludeDetails = $false,
    [string]$TeamsWebhookUrl = "https://vaxowave0.webhook.office.com/webhookb2/539220d7-1ddc-40b1-ab4d-8121a52244a8@45bdf2be-4562-4985-aa6d-5bcc311a3177/IncomingWebhook/5b83e1a2297e4de08f5acd13763c333c/f29b105a-daba-46a3-980b-f2ed53d840d1/V2TrnRj6k9-3eopRiN_IwGUdhOGJnPcaZyJ4tkcTq051Q1",
    [switch]$PostToTeams = $false
)

Write-Host "🔍 Getting daily costs for all subscriptions..." -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan

# Check if user is logged in to Azure
try {
    $context = Get-AzContext
    if (-not $context) {
        Write-Error "❌ Not logged in to Azure. Please run 'Connect-AzAccount' first."
        exit 1
    }
    Write-Host "✅ Connected to Azure as: $($context.Account.Id)" -ForegroundColor Green
} catch {
    Write-Error "❌ Azure PowerShell module not available. Please install Az module."
    exit 1
}

# Get current date for cost query
$currentDate = Get-Date -Format "yyyy-MM-dd"
$startDate = $currentDate
$endDate = (Get-Date).AddDays(1).ToString("yyyy-MM-dd")

Write-Host "📅 Getting costs for: $currentDate" -ForegroundColor Yellow

# Get all subscriptions
try {
    $subscriptions = Get-AzSubscription
    Write-Host "📋 Found $($subscriptions.Count) subscription(s)" -ForegroundColor Green
} catch {
    Write-Error "❌ Failed to get subscriptions: $($_.Exception.Message)"
    exit 1
}

$results = @()
$totalCost = 0

foreach ($subscription in $subscriptions) {
    Write-Host "🔍 Processing subscription: $($subscription.Name) ($($subscription.Id))" -ForegroundColor White
    
    try {
        # Set context to current subscription
        Set-AzContext -SubscriptionId $subscription.Id | Out-Null
        
        # Get cost data for the current day
        $costData = Invoke-AzRestMethod -Uri "https://management.azure.com/subscriptions/$($subscription.Id)/providers/Microsoft.CostManagement/query?api-version=2023-03-01" -Method POST -Payload @"
{
    "type": "ActualCost",
    "timeframe": "Custom",
    "timePeriod": {
        "from": "$startDate",
        "to": "$endDate"
    },
    "dataset": {
        "granularity": "Daily",
        "aggregation": {
            "totalCost": {
                "name": "PreTaxCost",
                "function": "Sum"
            }
        }
    }
}
"@
        
        if ($costData.StatusCode -eq 200) {
            $cost = ($costData.Content | ConvertFrom-Json)
            $dailyCost = 0
            
            if ($cost.properties.rows.Count -gt 0) {
                $dailyCost = [math]::Round($cost.properties.rows[0][0], 2)
            }
            
            # Get currency from the response, default to USD
            $currency = "USD"
            if ($cost.properties.columns.Count -gt 1) {
                $currencyColumn = $cost.properties.columns | Where-Object { $_.name -like "*Currency*" -or $_.name -eq "BillingCurrency" }
                if ($currencyColumn) {
                    $currency = $currencyColumn.name
                }
            }
            
            $result = [PSCustomObject]@{
                SubscriptionName = $subscription.Name
                SubscriptionId = $subscription.Id
                Date = $currentDate
                DailyCost = $dailyCost
                Currency = $currency
                Status = "Success"
            }
            
            $results += $result
            $totalCost += $dailyCost
            
            Write-Host "   💰 Daily cost: `$$dailyCost $currency" -ForegroundColor Green
        } else {
            Write-Warning "⚠️  Failed to get cost data for subscription $($subscription.Name): $($costData.StatusCode)"
            
            $result = [PSCustomObject]@{
                SubscriptionName = $subscription.Name
                SubscriptionId = $subscription.Id
                Date = $currentDate
                DailyCost = 0
                Currency = "USD"
                Status = "Failed - Status: $($costData.StatusCode)"
            }
            $results += $result
        }
    } catch {
        Write-Warning "⚠️  Error processing subscription $($subscription.Name): $($_.Exception.Message)"
        
        $result = [PSCustomObject]@{
            SubscriptionName = $subscription.Name
            SubscriptionId = $subscription.Id
            Date = $currentDate
            DailyCost = 0
            Currency = "USD"
            Status = "Error: $($_.Exception.Message)"
        }
        $results += $result
    }
}

# Display results
Write-Host ""
Write-Host "📊 Daily Cost Summary for $currentDate" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan

if ($OutputFormat -eq "Table") {
    if ($IncludeDetails) {
        $results | Format-Table -AutoSize
    } else {
        $results | Select-Object SubscriptionName, DailyCost, Currency, Status | Format-Table -AutoSize
    }
} elseif ($OutputFormat -eq "CSV") {
    $results | ConvertTo-Csv -NoTypeInformation
} elseif ($OutputFormat -eq "JSON") {
    $results | ConvertTo-Json -Depth 3
}

# Total summary
$successfulSubs = ($results | Where-Object { $_.Status -eq "Success" }).Count
$currency = "USD"  # Default to USD

# Try to get actual currency from successful results
$currencyFromResults = ($results | Where-Object { $_.Status -eq "Success" -and $_.Currency -ne "USD" } | Select-Object -First 1).Currency
if ($currencyFromResults) { 
    $currency = $currencyFromResults 
}

Write-Host ""
Write-Host "💰 Total Daily Cost Across All Subscriptions: `$$([math]::Round($totalCost, 2)) $currency" -ForegroundColor Green
Write-Host "✅ Successfully processed: $successfulSubs/$($subscriptions.Count) subscriptions" -ForegroundColor Green

# Output to file if specified
if ($OutputPath) {
    try {
        if ($OutputFormat -eq "CSV") {
            $results | Export-Csv -Path $OutputPath -NoTypeInformation
        } elseif ($OutputFormat -eq "JSON") {
            $results | ConvertTo-Json -Depth 3 | Out-File -FilePath $OutputPath
        } else {
            $results | Out-File -FilePath $OutputPath
        }
        Write-Host "💾 Results saved to: $OutputPath" -ForegroundColor Green
    } catch {
        Write-Warning "⚠️  Failed to save results to file: $($_.Exception.Message)"
    }
}

# Pipeline-friendly output for Azure DevOps
Write-Host "##vso[task.setvariable variable=TotalDailyCost]$([math]::Round($totalCost, 2))"
Write-Host "##vso[task.setvariable variable=CostCurrency]$currency"
Write-Host "##vso[task.setvariable variable=ProcessedSubscriptions]$successfulSubs"
Write-Host "##vso[task.setvariable variable=TotalSubscriptions]$($subscriptions.Count)"

# Post to Teams if requested
if ($PostToTeams -and $TeamsWebhookUrl) {
    Write-Host ""
    Write-Host "📢 Posting results to Teams..." -ForegroundColor Yellow
    
    try {
        # Create adaptive card for Teams
        $teamsCard = @{
            "@type" = "MessageCard"
            "@context" = "https://schema.org/extensions"
            "summary" = "Daily Azure Cost Report"
            "themeColor" = "0078D4"
            "title" = "💰 Daily Azure Cost Report - $currentDate"
            "sections" = @(
                @{
                    "activityTitle" = "💰 Daily Cost Summary"
                    "activitySubtitle" = "Total accumulated costs across all Azure subscriptions"
                    "facts" = @(
                        @{
                            "name" = "📅 Report Date"
                            "value" = $currentDate
                        },
                        @{
                            "name" = "� Total Daily Cost"
                            "value" = "`$" + ("{0:N2}" -f $totalCost) + " USD"
                        },
                        @{
                            "name" = "📋 Processing Status"
                            "value" = "$successfulSubs of $($subscriptions.Count) subscriptions processed successfully"
                        },
                        @{
                            "name" = "📈 Active Subscriptions"
                            "value" = ($results | Where-Object { $_.DailyCost -gt 0 -and $_.Status -eq "Success" }).Count.ToString() + " subscription(s) with costs today"
                        }
                    )
                    "markdown" = $true
                }
            )
        }
        
        # Add status section if there were failures
        $failedSubs = $results | Where-Object { $_.Status -ne "Success" }
        if ($failedSubs.Count -gt 0) {
            $statusSection = @{
                "activityTitle" = "⚠️ Processing Issues"
                "activitySubtitle" = "Subscriptions with errors"
                "text" = ""
                "markdown" = $true
            }
            
            $statusSection.text = "**Failed to process:**`n`n"
            foreach ($failed in $failedSubs | Select-Object -First 5) {
                $statusSection.text += "• **$($failed.SubscriptionName)**: $($failed.Status)`n"
            }
            
            $teamsCard.sections += $statusSection
        }
        
        # Convert to JSON
        $teamsPayload = $teamsCard | ConvertTo-Json -Depth 10
        
        # Send to Teams
        $null = Invoke-RestMethod -Uri $TeamsWebhookUrl -Method Post -Body $teamsPayload -ContentType "application/json"
        
        Write-Host "✅ Successfully posted to Teams!" -ForegroundColor Green
        
    } catch {
        Write-Warning "⚠️  Failed to post to Teams: $($_.Exception.Message)"
        Write-Host "   Teams webhook URL: $TeamsWebhookUrl" -ForegroundColor Gray
    }
}
