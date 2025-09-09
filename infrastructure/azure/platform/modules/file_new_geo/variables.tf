# General variables
variable "location" {
  description = "Specifies the main Azure region in the tenant."
  type        = string
  sensitive   = false
}

variable "suffix" {
  description = "Specifies the suffix for all Azure resources."
  type        = string
  sensitive   = false
  validation {
    condition     = length(var.suffix) >= 2 && length(var.suffix) <= 8
    error_message = "Please specify a suffix with more than two and less than 8 characters."
  }
  validation {
    condition     = length(regexall("[^[:alnum:]]", var.suffix)) <= 0
    error_message = "Please specify a suffix only containing alphanumeric characters."
  }
}

variable "tags" {
  description = "Specifies the tags that you want to apply to all resources."
  type        = map(string)
  sensitive   = false
  default     = {}
  validation {
    condition     = length([for key, value in var.tags : true if length(regexall("[^[:lower:]]", key)) > 0 || length(regexall("[^[:lower:]]", value)) > 0]) <= 0
    error_message = "Please spaecify a lower case key and value for all tags."
  }
}

variable "diagnostics_setting_name" {
  description = "Specifies the common name used for diagnostic settings to log analytics workspaces."
  type        = string
  sensitive   = false
  validation {
    condition     = length(var.diagnostics_setting_name) >= 1 && length(var.diagnostics_setting_name) <= 80
    error_message = "Please specify a valid name with at least one and up to 80 characters."
  }
}

# File New Geo variables
variable "geo_name" {
  description = "Specifies the geo name."
  type        = string
  sensitive   = false
  validation {
    condition     = length(var.geo_name) >= 2 && length(var.geo_name) <= 8
    error_message = "Please specify a geo name with more than two and less than 8 characters."
  }
}

variable "geo_platform_subscription_id" {
  description = "Specifies the geo platform subscription id."
  type        = string
  sensitive   = false
  validation {
    condition     = length(regexall("^[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}$", var.geo_platform_subscription_id)) == 1
    error_message = "Please specify a valid subscription id that follows the expected pattern."
  }
}

variable "geo_region_names" {
  description = "Specifies the regions contained in the geo."
  type        = list(string)
  sensitive   = false
}

variable "enable_sentinel" {
  description = "Specifies whether the sentinel deployment should be enabled."
  type        = bool
  sensitive   = false
  nullable    = false
  default     = false
}

variable "allowed_resource_providers" {
  description = "Specifies the list of allowed resource providers."
  type        = list(string)
  sensitive   = false
}

variable "denied_resource_types" {
  description = "Specifies the list of denied resource types within the list of allowed resource providers."
  type        = list(string)
  sensitive   = false
}

variable "spoke_prefix" {
  description = "Specifies the prefix to be used for spoke virtual networks."
  type        = string
  sensitive   = false
  validation {
    condition     = length(var.spoke_prefix) >= 2 && length(var.spoke_prefix) <= 10
    error_message = "Please specify a spoke prefix with more than two and less than 10 characters."
  }
}

# File New Tenant variables
variable "artifacts_management_group_root_setup_completed" {
  description = "Specifies whether the policy deployment at the root management group has completed successfully."
  type        = bool
  sensitive   = false
}

variable "management_group_root_id" {
  description = "Specifies the id of the root management group."
  type        = string
  sensitive   = false
  validation {
    condition     = length(split("/", var.management_group_root_id)) == 5
    error_message = "Please specify a management group id that consists of 5 segments (e.g. '/providers/Microsoft.Management/managementGroups/my-mg-name')."
  }
}

variable "management_group_landing_zones_id" {
  description = "Specifies the id of the landing zones management group."
  type        = string
  sensitive   = false
  validation {
    condition     = length(split("/", var.management_group_landing_zones_id)) == 5
    error_message = "Please specify a management group id that consists of 5 segments (e.g. '/providers/Microsoft.Management/managementGroups/my-mg-name')."
  }
}

variable "management_group_platform_id" {
  description = "Specifies the id of the platform management group."
  type        = string
  sensitive   = false
  validation {
    condition     = length(split("/", var.management_group_platform_id)) == 5
    error_message = "Please specify a management group id that consists of 5 segments (e.g. '/providers/Microsoft.Management/managementGroups/my-mg-name')."
  }
}

variable "network_manager_resource_id" {
  description = "Specifies the resource Id of the Azure Virtual Network Manager instance."
  type        = string
  sensitive   = false
  validation {
    condition     = length(split("/", var.network_manager_resource_id)) == 9 || var.network_manager_resource_id == ""
    error_message = "Please specify a valid resource ID."
  }
}

variable "network_ddos_protection_plan_id" {
  description = "Specifies the resource Id of the Azure DDoS protection plan."
  type        = string
  sensitive   = false
  nullable    = false
  default     = ""
  validation {
    condition     = length(split("/", var.network_ddos_protection_plan_id)) == 9 || var.network_ddos_protection_plan_id == ""
    error_message = "Please specify a valid resource ID."
  }
}
