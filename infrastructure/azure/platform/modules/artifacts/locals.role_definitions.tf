locals {
  # Load file paths
  azure_role_definitions_filepaths_json = local.azure_role_definitions_library_path == "" ? [] : tolist(fileset(local.azure_role_definitions_library_path, "**/*.{json,json.tftpl}"))
  azure_role_definitions_filepaths_yaml = local.azure_role_definitions_library_path == "" ? [] : tolist(fileset(local.azure_role_definitions_library_path, "**/*.{yml,yml.tftpl,yaml,yaml.tftpl}"))

  # Load file content
  azure_role_definitions_json = {
    for filepath in local.azure_role_definitions_filepaths_json :
    filepath => jsondecode(templatefile("${local.azure_role_definitions_library_path}/${filepath}", local.template_variables))
  }
  azure_role_definitions_yaml = {
    for filepath in local.azure_role_definitions_filepaths_yaml :
    filepath => yamldecode(templatefile("${local.azure_role_definitions_library_path}/${filepath}", local.template_variables))
  }

  # Merge data
  azure_role_definitions = merge(
    local.azure_role_definitions_json,
    local.azure_role_definitions_yaml
  )
}
