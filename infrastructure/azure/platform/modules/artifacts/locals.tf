locals {
  azure_policy_definitions_library_path = "./**/AzurePolicyDefinitions"
  azure_policy_sets_library_path        = "./**/AzurePolicySets"
  azure_role_definitions_library_path   = "./**/AzureCustomRoleDefinitions"

  default_template_variables = {
    # General parameters
    default_location = var.location
    scope_id         = var.deployment_scope

    # Other supported parameters
    scope_id_root             = ""
    scope_id_platform         = ""
    scope_id_identity         = ""
    scope_id_management       = ""
    scope_id_connectivity     = ""
    scope_id_landing_zones    = ""
    scope_id_playground       = ""
    scope_id_decomissioned    = ""
    scope_id_geo              = ""
    scope_id_geo_corp         = ""
    scope_id_geo_cloud_native = ""
  }

  template_variables = merge(local.default_template_variables, var.custom_template_variables)

  custom_role_suffix = var.custom_role_suffix != "" ? "-${var.custom_role_suffix}" : ""
}
