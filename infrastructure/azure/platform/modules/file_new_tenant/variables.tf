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
    error_message = "Please specify a lower case key and value for all tags."
  }
}

# File New Tenant variables
variable "organization_name" {
  description = "Specifies the name of the organization."
  type        = string
  sensitive   = false
  validation {
    condition     = length(var.organization_name) >= 2
    error_message = "Please specify an orgaization name with more than two characters."
  }
}

variable "locations_supported" {
  description = "Specifies the supported Azure regions in the tenant."
  type        = list(string)
  sensitive   = false
  validation {
    condition     = length(var.locations_supported) == length(distinct(var.locations_supported))
    error_message = "Please specify a list of locations, where each item is unique."
  }
}

variable "hub_prefix" {
  description = "Specifies the prefix to be used for hub virtual networks."
  type        = string
  sensitive   = false
  validation {
    condition     = length(var.hub_prefix) >= 2 && length(var.hub_prefix) <= 10
    error_message = "Please specify a hub prefix with more than two and less than 10 characters."
  }
}

variable "spoke_prefix" {
  description = "Specifies the prefix to be used for spoke virtual networks."
  type        = string
  sensitive   = false
  default     = "spoke-vnet"
  validation {
    condition     = length(var.spoke_prefix) >= 2 && length(var.spoke_prefix) <= 10
    error_message = "Please specify a spoke prefix with more than two and less than 10 characters."
  }
}

variable "environments" {
  description = "Specifies the network environments created within the environment."
  type        = list(string)
  sensitive   = false
  validation {
    condition     = length([for item in var.environments : true if length(regexall("[^[:lower:]]", item)) > 0]) <= 0
    error_message = "Please specify environment names only containing lowercase characters."
  }
}

variable "subscription_ids_connectivity" {
  description = "Specifies the subscription ids which must be moved under the platform connectivity management group."
  type        = list(string)
  sensitive   = false
  default     = []
  validation {
    condition     = length([for item in var.subscription_ids_connectivity : true if length(regexall("^[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}$", item)) <= 0]) <= 0
    error_message = "Please provide connectivity subscription ids that follow the expected pattern."
  }
  validation {
    condition     = length(var.subscription_ids_connectivity) == length(distinct(var.subscription_ids_connectivity))
    error_message = "Please specify a list of subscription ids, where each item is unique."
  }
}

variable "subscription_ids_management" {
  description = "Specifies the subscription ids which must be moved under the platform management management group."
  type        = list(string)
  sensitive   = false
  default     = []
  validation {
    condition     = length([for item in var.subscription_ids_management : true if length(regexall("^[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}$", item)) <= 0]) <= 0
    error_message = "Please provide management subscription ids that follow the expected pattern."
  }
  validation {
    condition     = length(var.subscription_ids_management) == length(distinct(var.subscription_ids_management))
    error_message = "Please specify a list of subscription ids, where each item is unique."
  }
}

variable "global_platform_subscription_id" {
  description = "Specifies the global platform subscription id which must be moved under the connectivity management group."
  type        = string
  sensitive   = false
  validation {
    condition     = length(regexall("^[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}$", var.global_platform_subscription_id)) == 1
    error_message = "Please provide a global platform subscription id that follows the expected pattern."
  }
}

variable "enable_ddos_protection_plan" {
  description = "Specifies whether the ddos protection plan deployment should be enabled."
  type        = bool
  sensitive   = false
  nullable    = false
  default     = false
}

variable "enable_management_group_settings_update" {
  description = "Specifies whether the management group settings should be updated. This will force the playground management group to be the default management group for subscriptions and will enforce Entra ID permissions for management group creation."
  type        = bool
  sensitive   = false
  nullable    = false
  default     = false
}

variable "enable_cloud_security_benchmark_settings_update" {
  description = "Specifies whether the cloud security benchmark settings should be updated to be in line with the platform capabilities and requirements."
  type        = bool
  sensitive   = false
  nullable    = false
  default     = true
}

variable "deploy_test_vms" {
  description = "Specifies whether test VMs should be deployed for connectivity testing."
  type        = bool
  sensitive   = false
  nullable    = false
  default     = false
}
