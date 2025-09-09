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

# File New Region variables
variable "region_platform_subscription_id" {
  description = "Specifies the subscription id used for regional resources."
  type        = string
  sensitive   = false
  validation {
    condition     = length(regexall("^[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}$", var.region_platform_subscription_id)) == 1
    error_message = "Please specify a valid subscription id that follows the expected pattern."
  }
}

# File New Geo variables
variable "log_analytics_workspace_id" {
  type        = string
  sensitive   = false
  description = "Specifies the resource ID of a log analytics workspace, where the log data should be stored."
  default     = ""
  validation {
    condition     = length(split("/", var.log_analytics_workspace_id)) == 9 || var.log_analytics_workspace_id == ""
    error_message = "Please specify a valid resource ID."
  }
}

# File New Tenant variables
variable "artifacts_management_group_root_setup_completed" {
  description = "Specifies whether the policy deployment at the root management group has completed successfully."
  type        = bool
  sensitive   = false
}
