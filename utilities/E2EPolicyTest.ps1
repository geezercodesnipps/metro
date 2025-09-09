# Define the endpoint and deployment details
$Endpoint = "https://assist-swedencentral-azopenai.openai.azure.com/"
$DeploymentName = "gpt-4o"

# Subscription context
$SubId = "/subscriptions/be25820a-df86-4794-9e95-6a45cd5c0941"

# Define file paths for meta prompt and policy definition
$MetaPromptFile = "./utilities/aiPolicyAssignmentInstructions.txt"

#$PolicyDefinitionFile = "./infrastructure/platform/definitions/APIM/AzurePolicyDefinitions/Deny-APIM-TLS.json"

$PolicyDefinitionId = "/providers/Microsoft.Authorization/policyDefinitions/1e30110a-5ceb-460c-a204-c1c3969c6d62"
$ScriptOutputLocation = "./utilities/PolicyAssignmentsScripts/PolicyAssignment.ps1"

# Define new assistant for generating policy tests
$TestMetaPromptFile = "./utilities/aiPolicyTestInstructions.txt"
$PolicyAssignment = $scriptContent
$TestScriptOutputLocation = "./utilities/PolicyTestScripts/"

# Define a log file for capturing outputs and errors
$LogFilePath = Join-Path -Path $TestScriptOutputLocation -ChildPath "PolicyTestLogging.txt"

# Retrieve the policy definition and convert it to JSON
try {
    $PolicyDefinition = Get-AzPolicyDefinition -id $PolicyDefinitionId | ConvertTo-Json -Depth 100
} catch {
    Write-Error "Failed to retrieve policy definition: $_"
    exit
}

# Create a new assistant for policy assignment
try {
    $NewAssistant = New-AzOpenAIAssistant -MetaPromptFile $MetaPromptFile -Endpoint $Endpoint -model $DeploymentName -AssistantName "AzPolicyAssigner"
} catch {
    Write-Error "Failed to create new assistant: $_"
    exit
}

# Taking a brake to ensure assignment has propagated

Start-Sleep -Seconds 30

# Start a thread to evaluate the policy
try {
    $EvaluatePolicy = Start-AzOpenAIAssistantThreadWithMessages -Endpoint $Endpoint -AssistantId $NewAssistant.id -MessageContent $PolicyDefinition
    Write-Output $EvaluatePolicy
} catch {
    Write-Error "Failed to evaluate policy: $_"
    exit
}

# Retrieve the policy assignment file
try {
    $PolicyAssignmentFile = Get-AzOpenAIAssistantOutputFiles -Endpoint $Endpoint | Where-Object { $_.filename -like "/mnt/data/assignment*" }
    Get-AzOpenAIAssistantOutputFiles -Endpoint $Endpoint -FileId $PolicyAssignmentFile.id -LocalFilePath $ScriptOutputLocation
} catch {
    Write-Error "Failed to retrieve policy assignment file: $_"
    exit
}

# Execute the AI-generated PowerShell script
try {
    $scriptContent = Get-Content -Path $ScriptOutputLocation -Raw
    $Execute = Invoke-Expression $scriptContent
    Write-Output $Execute.Method
    Write-Output $Execute.statuscode
    Write-Output ($Execute.content | ConvertFrom-Json -Depth 100)
} catch {
    Write-Error "Failed to execute policy assignment script: $_"
    exit
}


try {
    # Create a new assistant for generating policy tests
    $NewTestAssistant = New-AzOpenAIAssistant -MetaPromptFile $TestMetaPromptFile -Endpoint $Endpoint -model $DeploymentName -AssistantName "AzPolicyTestAssistant"
} catch {
    Write-Error "Failed to create new test assistant: $_"
    exit
}

# Start a thread to evaluate the policy assignment and generate tests
try {
    $EvaluatePolicyTests = Start-AzOpenAIAssistantThreadWithMessages -Endpoint $Endpoint -AssistantId $NewTestAssistant.id -MessageContent $PolicyAssignment
    Write-Output $EvaluatePolicyTests
} catch {
    Write-Error "Failed to evaluate policy assignment tests: $_"
    exit
}

try {
    # Retrieve the generated policy test scripts
    $PolicyTestScripts = Get-AzOpenAIAssistantOutputFiles -Endpoint $Endpoint | Where-Object { $_.filename -like "/mnt/data/policy*" }
} catch {
    Write-Error "Failed to retrieve policy test scripts: $_"
    exit
}

# Initialize the counter for unique filenames
$Counter = 1

# Loop through each policy test script
foreach ($PolicyTestScript in $PolicyTestScripts) {
    # Generate a unique filename with the .ps1 extension
    $UniqueFileName = "PolicyTestScript_$($Counter).ps1"
    $FullFilePath = Join-Path -Path $TestScriptOutputLocation -ChildPath $UniqueFileName

    try {
        # Get the file and save it to the unique file path
        Get-AzOpenAIAssistantOutputFiles -Endpoint $Endpoint -FileId $PolicyTestScript.id -LocalFilePath $FullFilePath

        # Read the content of the saved script file
        $scriptContent = Get-Content -Path $FullFilePath -Raw

        Start-Sleep -Seconds 30

        # Execute the script content and capture the output
        $executionResult = Invoke-Expression $scriptContent

        # Log the details to the log file
        Add-Content -Path $LogFilePath -Value "Execution result of $($UniqueFileName):"
        if ($executionResult -is [Microsoft.Azure.Commands.Profile.Models.PSHttpResponse]) {
            Add-Content -Path $LogFilePath -Value "Status Code: $($executionResult.StatusCode)"
            Add-Content -Path $LogFilePath -Value "Headers: $($executionResult.Headers)"
            Add-Content -Path $LogFilePath -Value "Content: $($executionResult.Content)"
        } else {
            Add-Content -Path $LogFilePath -Value $executionResult
        }
    } catch {
        # Log the error to the log file
        Add-Content -Path $LogFilePath -Value "Error executing $($UniqueFileName): $_"
    }

    # Increment the counter for the next iteration
    $Counter++
}

# Clean up the environment
try {
    Remove-AzOpenAIAssistantFiles -Endpoint $Endpoint
    Remove-AzOpenAIAssistants -Endpoint $Endpoint
    Get-AzPolicyAssignment -scope $SubId | Remove-AzPolicyAssignment -Verbose
} catch {
    Write-Error "Failed to clean up the environment: $_"
}
