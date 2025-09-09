locals {
  suffix                   = "${lower(var.suffix)}-${lower(var.environment)}-${lower(var.location)}"
  hub_prefix               = lower(var.hub_prefix)
  spoke_prefix             = lower(var.spoke_prefix)
  environment_short_suffix = lower(substr(var.environment, 0, 1))
}
