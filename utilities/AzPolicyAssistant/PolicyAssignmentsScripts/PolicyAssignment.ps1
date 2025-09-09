
# Define the policy assignment payload
$policyAssignmentBody = @{
    properties = @{
        displayName = "Require a tag and its value on resources"
        policyDefinitionId = "/providers/Microsoft.Authorization/policyDefinitions/1e30110a-5ceb-460c-a204-c1c3969c6d62"
        scope = "/subscriptions/be25820a-df86-4794-9e95-6a45cd5c0941"
        parameters = @{
            tagName = @{
                value = "Environment"  # Example tag name
            }
            tagValue = @{
                value = "Production"  # Example tag value
            }
            effect = @{
                value = "Deny"
            }
        }
    }
} | ConvertTo-Json -Depth 10

# Assign the policy using Invoke-AzRestMethod
$assignmentUri = "https://management.azure.com/subscriptions/be25820a-df86-4794-9e95-6a45cd5c0941/providers/Microsoft.Authorization/policyAssignments/requireTagAssignment?api-version=2021-06-01"

Invoke-AzRestMethod -Method Put -Uri $assignmentUri -Payload $policyAssignmentBody
