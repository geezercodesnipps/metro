variable "location" {
  description = "Specifies the region for all Azure resources."
  type        = string
  sensitive   = false
}

variable "deployment_scope" {
  description = "Specifies the deployment scope of the deployment. Must either start with '/subscriptons/...' or must be a management group name."
  type        = string
  sensitive   = false
  validation {
    condition     = startswith(var.deployment_scope, "/subscriptions/") || startswith(var.deployment_scope, "/providers/Microsoft.Management/managementGroups/")
    error_message = "Please provide a valid deployment scope."
  }
}

variable "azure_resources_library_folder" {
  description = "Specifies the base folder to the Azure resources library."
  type        = string
  sensitive   = false
}

variable "custom_template_variables" {
  description = "Specifies custom template variables to use for the deployment when loading the Azure resources from the library path."
  type        = map(string)
  sensitive   = false
  default     = {}
}

variable "custom_role_suffix" {
  description = "Specifies the suffix for custom roles deployed at the scope."
  type        = string
  sensitive   = false
  default     = ""
  validation {
    condition     = length(var.custom_role_suffix) >= 2 && length(var.custom_role_suffix) <= 8
    error_message = "Please specify a valid suffix with more than two and less than 8 characters."
  }
}
