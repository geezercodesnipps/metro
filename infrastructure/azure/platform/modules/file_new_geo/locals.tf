locals {
  suffix = "${lower(var.suffix)}-${lower(var.geo_name)}"

  # Cross-validation for denied resource types against allowed resource providers
  invalid_denied_resource_types = [
    for item in var.denied_resource_types : item
    if !contains(var.allowed_resource_providers, split("/", item)[0])
  ]

  # Fetch resource provider resource types and create flat list for policy assignment
  allowed_resource_types = flatten([
    for provider_idx, provider_item in var.allowed_resource_providers : [
      for resource_idx, resource_item in data.azapi_resource_action.resource_provider[provider_item].output.resourceTypes :
      "${provider_item}/${resource_item.resourceType}"
    ]
  ])
}
