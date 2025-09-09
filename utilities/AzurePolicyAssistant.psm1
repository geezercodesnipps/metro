# Save this as AzurePolicyAssistant.psm1

# Define the functions of the module

function New-AzPolicyAssigner {
    param (
        [string]$MetaPromptFile,
        [string]$Endpoint,
        [string]$Model,
        [string]$AssistantName
    )
    $NewAssistant = New-AzOpenAIAssistant -MetaPromptFile $MetaPromptFile `
                                          -Endpoint $Endpoint `
                                          -model $Model `
                                          -AssistantName $AssistantName
    return $NewAssistant
}

function Start-EvaluatePolicy {
    param (
        [string]$Endpoint,
        [string]$AssistantId,
        [string]$MessageContent
    )
    $EvaluatePolicy = Start-AzOpenAIAssistantThreadWithMessages -Endpoint $Endpoint `
                                                                -AssistantId $AssistantId `
                                                                -MessageContent $MessageContent
    return $EvaluatePolicy
}

function Get-PolicyAssignmentFile {
    param (
        [string]$Endpoint
    )
    $PolicyAssignmentFile = Get-AzOpenAIAssistantOutputFiles -Endpoint $Endpoint | Where-Object { $_.filename -like "/mnt/data/assignment*" }
    return $PolicyAssignmentFile
}

function Download-PolicyAssignmentFile {
    param (
        [string]$Endpoint,
        [string]$FileId,
        [string]$LocalFilePath
    )
    Get-AzOpenAIAssistantOutputFiles -Endpoint $Endpoint -FileId $FileId -LocalFilePath $LocalFilePath
}

function Execute-PolicyAssignment {
    param (
        [string]$ScriptPath
    )
    $scriptContent = Get-Content -Path $ScriptPath -Raw
    $Execute = Invoke-Expression $scriptContent
    Write-Output $Execute.Method
    Write-Output $Execute.statuscode
    Write-Output ($Execute.content | ConvertFrom-Json -Depth 100)
}

function Generate-PolicyTests {
    param (
        [string]$MetaPromptFile,
        [string]$Endpoint,
        [string]$Model,
        [string]$AssistantName,
        [string]$PolicyAssignment
    )
    $NewAssistant = New-AzOpenAIAssistant -MetaPromptFile $MetaPromptFile `
                                          -Endpoint $Endpoint `
                                          -model $Model `
                                          -AssistantName $AssistantName

    $EvaluatePolicy = Start-AzOpenAIAssistantThreadWithMessages -Endpoint $Endpoint `
                                                                -AssistantId $NewAssistant.id `
                                                                -MessageContent $PolicyAssignment

    return $EvaluatePolicy
}

function Get-PolicyTestScripts {
    param (
        [string]$Endpoint
    )
    $PolicyTestScripts = Get-AzOpenAIAssistantOutputFiles -Endpoint $Endpoint | Where-Object { $_.filename -like "/mnt/data/policy*" }
    return $PolicyTestScripts
}

function Download-And-Execute-TestScripts {
    param (
        [string]$Endpoint,
        [array]$PolicyTestScripts,
        [string]$OutputDirectory,
        [string]$LogFilePath
    )
    # Initialize the counter for unique filenames
    $Counter = 1

    foreach ($PolicyTestScript in $PolicyTestScripts) {
        # Generate a unique filename with the .ps1 extension
        $UniqueFileName = "DemoPolicyTestScript_$($Counter).ps1"

        # Combine the output directory with the unique filename
        $FullFilePath = Join-Path -Path $OutputDirectory -ChildPath $UniqueFileName

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
}

function Clean-Up-Environment {
    param (
        [string]$Endpoint
    )
    Remove-AzOpenAIAssistantFiles -Endpoint $Endpoint
    Remove-AzOpenAIAssistants -Endpoint $Endpoint
}

# Export the functions as cmdlets of the module
Export-ModuleMember -Function * -Alias *
