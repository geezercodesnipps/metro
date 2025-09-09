resource "azurerm_policy_definition" "policy_definitions" {
  for_each = local.azure_policy_definitions

  name                = try(each.value.name, "")
  management_group_id = startswith(var.deployment_scope, "/subscriptions/") ? null : var.deployment_scope

  display_name = try(each.value.properties.displayName, "")
  description  = try(each.value.properties.description, "")
  policy_type  = try(each.value.properties.policyType, "")
  mode         = try(each.value.properties.mode, "")
  metadata     = jsonencode(try(each.value.properties.metadata, ""))
  parameters   = jsonencode(try(each.value.properties.parameters, ""))
  policy_rule  = jsonencode(try(each.value.properties.policyRule, ""))

  lifecycle {
    create_before_destroy = true
  }
}

resource "azurerm_policy_set_definition" "policy_set_definitions" {
  for_each = local.azure_policy_set_definitions

  name                = try(each.value.name, "")
  management_group_id = startswith(var.deployment_scope, "/subscriptions/") ? null : var.deployment_scope

  display_name = try(each.value.properties.displayName, "")
  description  = try(each.value.properties.description, "")
  policy_type  = try(each.value.properties.policyType, "")
  metadata     = jsonencode(try(each.value.properties.metadata, ""))
  parameters   = jsonencode(try(each.value.properties.parameters, ""))
  dynamic "policy_definition_group" {
    for_each = try(each.value.properties.policyDefinitionGroups, [])
    content {
      name         = policy_definition_group.value.name
      category     = policy_definition_group.value.category
      display_name = policy_definition_group.value.displayName
      description  = policy_definition_group.value.description
    }
  }
  dynamic "policy_definition_reference" {
    for_each = try(each.value.properties.policyDefinitions, [])
    content {
      policy_definition_id = policy_definition_reference.value.policyDefinitionId
      parameter_values     = try(jsonencode(policy_definition_reference.value.parameters), null)
      policy_group_names   = try(policy_definition_reference.value.groupNames, [])
      reference_id         = policy_definition_reference.value.policyDefinitionReferenceId
    }
  }

  depends_on = [
    azurerm_policy_definition.policy_definitions
  ]
}

resource "azurerm_role_definition" "role_definitions" {
  for_each = local.azure_role_definitions

  name  = "${try(each.value.name, "")}${local.custom_role_suffix}"
  scope = var.deployment_scope

  assignable_scopes = try(each.value.properties.assignableScopes, [])
  description       = try(each.value.properties.description, "")
  permissions {
    actions          = try(each.value.properties.permissions[0].actions, [])
    not_actions      = try(each.value.properties.permissions[0].notActions, [])
    data_actions     = try(each.value.properties.permissions[0].dataActions, [])
    not_data_actions = try(each.value.properties.permissions[0].notDataActions, [])
  }
}
