# Walk-through of Assistant API to assign Azure Policy and generate tests

$Endpoint = "https://assist-swedencentral-azopenai.openai.azure.com/"
$DeplomentName = "gpt-4o"
$MetaPromptFile = "./utilities/AzPolicyAssistant/aiPolicyAssignmentInstructions.txt"
$PolicyDefinition = Get-AzPolicyDefinition -id "/providers/Microsoft.Authorization/policyDefinitions/6300012e-e9a4-4649-b41f-a85f5c43be91" | ConvertTo-Json -Depth 100
#$PolicyDefinitionFile = Get-Content -Path ./infrastructure/platform/definitions/APIM/AzurePolicyDefinitions/Deny-APIM-TLS.json -Raw
$ScriptOutputLocation = "./utilities/AzPolicyAssistant/PolicyAssignmentsScripts/SWATDemo.ps1"

$NewAssistant = New-AzOpenAIAssistant -MetaPromptFile $MetaPromptFile `
                                      -Endpoint $Endpoint `
                                      -model $DeplomentName `
                                      -AssistantName "AzPolicyAssigner"

$EvaluatePolicy = Start-AzOpenAIAssistantThreadWithMessages -Endpoint $Endpoint `
                                                            -AssistantId $NewAssistant.id `
                                                            -MessageContent $PolicyDefinition

Write-Output $EvaluatePolicy

$PolicyAssignmentFile = Get-AzOpenAIAssistantOutputFiles -Endpoint $Endpoint | Where-Object {$_.filename -like "/mnt/data/assignment*"}

Get-AzOpenAIAssistantOutputFiles -Endpoint $Endpoint -FileId $PolicyAssignmentFile.id -LocalFilePath $ScriptOutputLocation

# Invoke-Expression for executing the AI generated PS snippet during runtime
$scriptContent = Get-Content -Path $ScriptOutputLocation -Raw

# Assign the Azure Policy
$Execute = Invoke-Expression $scriptContent
$Execute.Method
$Execute.statuscode
$Execute.content | convertfrom-json -Depth 100

# Generate Azure Policy tests based on the assignment

$MetaPromptFile = "./utilities/AzPolicyAssistant/aiPolicyTestInstructions.txt"
$PolicyAssignment = $scriptContent
$ScriptOutputLocation = "./utilities/AzPolicyAssistant/PolicyTestScripts/"

$NewAssistant = New-AzOpenAIAssistant -MetaPromptFile $MetaPromptFile `
                                      -Endpoint $Endpoint `
                                      -model $DeplomentName `
                                      -AssistantName "AzPolicyTestAssistant"

$EvaluatePolicy = Start-AzOpenAIAssistantThreadWithMessages -Endpoint $Endpoint `
                                                            -AssistantId $NewAssistant.id `
                                                            -MessageContent $PolicyAssignment

Write-Output $EvaluatePolicy

Get-AzOpenAIAssistantOutputFiles -Endpoint $Endpoint

$PolicyTestScripts = Get-AzOpenAIAssistantOutputFiles -Endpoint $Endpoint | Where-Object {$_.filename -like "/mnt/data/policy*"}

# Define a log file for capturing outputs and errors
$LogFilePath = Join-Path -Path $ScriptOutputLocation -ChildPath "DemoExecutionLog.txt"

# Initialize the counter for unique filenames
$Counter = 1

# Loop through each policy test script
foreach ($PolicyTestScript in $PolicyTestScripts) {
    # Generate a unique filename with the .ps1 extension
    $UniqueFileName = "DemoPolicyTestScript_$($Counter).ps1"

    # Combine the output directory with the unique filename
    $FullFilePath = Join-Path -Path $ScriptOutputLocation -ChildPath $UniqueFileName

    # Get the file and save it to the unique file path
    Get-AzOpenAIAssistantOutputFiles -Endpoint $Endpoint -FileId $PolicyTestScript.id -LocalFilePath $FullFilePath

    # Read the content of the saved script file
    $scriptContent = Get-Content -Path $FullFilePath -Raw

    Start-Sleep -Seconds 30

    # Execute the script content and capture the output
    try {
        $executionResult = Invoke-Expression $scriptContent
        # Extract and log the properties of the PSHttpResponse object
        if ($executionResult -is [Microsoft.Azure.Commands.Profile.Models.PSHttpResponse]) {
            $statusCode = $executionResult.StatusCode
            $headers = $executionResult.Headers
            $content = $executionResult.Content

            # Log the details to the console
            Write-Output "Execution result of $($UniqueFileName):"
            Write-Output "Status Code: $statusCode"
            Write-Output "Headers: $headers"
            Write-Output "Content: $content"

            # Log the details to the log file
            Add-Content -Path $LogFilePath -Value "Execution result of $($UniqueFileName):"
            Add-Content -Path $LogFilePath -Value "Status Code: $statusCode"
            Add-Content -Path $LogFilePath -Value "Headers: $headers"
            Add-Content -Path $LogFilePath -Value "Content: $content"
        } else {
            # Log other types of results to the console and log file
            Write-Output "Execution result of $($UniqueFileName):"
            Write-Output $executionResult
            Add-Content -Path $LogFilePath -Value "Execution result of $($UniqueFileName):"
            Add-Content -Path $LogFilePath -Value $executionResult
        }
    }
    catch {
        # Log the error to the console and log file
        Write-Host "Error executing $($UniqueFileName):" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Add-Content -Path $LogFilePath -Value "Error executing $($UniqueFileName):"
        Add-Content -Path $LogFilePath -Value $_.Exception.Message
    }

    # Increment the counter for the next iteration
    $Counter++
}

# Clean up the environment

Remove-AzOpenAIAssistantFiles -Endpoint $Endpoint
Remove-AzOpenAIAssistants -Endpoint $Endpoint
