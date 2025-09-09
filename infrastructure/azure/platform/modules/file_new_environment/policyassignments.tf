resource "azurerm_management_group_policy_assignment" "management_group_policy_assignment_avnm_regional_spokes" {
  name                 = "vnets-${var.location}-${local.environment_short_suffix}"
  policy_definition_id = azurerm_policy_definition.network_manager_regional_spoke_vnets_policy_definition.id
  management_group_id  = var.management_group_id

  display_name = "Azure Virtual Network Manager regional spoke VNets (${local.suffix})"
  description  = "This policy assignment ensures regional spoke VNets are added to their corresponding Network Manager network group"
}
