output "artifacts_setup_completed" {
  description = "Specifies whether the policy deployment has completed successfully."
  value       = true
  sensitive   = false

  depends_on = [
    azurerm_policy_definition.policy_definitions,
    azurerm_policy_set_definition.policy_set_definitions,
    azurerm_role_definition.role_definitions,
  ]
}
