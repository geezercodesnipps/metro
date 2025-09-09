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

variable "environment" {
  description = "Specifies the environment of the deployment."
  type        = string
  sensitive   = false
  default     = "dev"
  validation {
    condition     = length(regexall("[^[:lower:]]", var.environment)) <= 0
    error_message = "Please specify an environment name only containing lowercase characters."
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

# File New Environment variables
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
  validation {
    condition     = length(var.spoke_prefix) >= 2 && length(var.spoke_prefix) <= 10
    error_message = "Please specify a spoke prefix with more than two and less than 10 characters."
  }
}

variable "environment_network_subscription_id" {
  description = "Specifies the address space of the network hub."
  type        = string
  sensitive   = false
  validation {
    condition     = length(regexall("^[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}$", var.environment_network_subscription_id)) == 1
    error_message = "Please specify a valid subscription id that follows the expected pattern."
  }
}

variable "address_space_network_hub" {
  description = "Specifies the address space of the network hub."
  type        = string
  sensitive   = false
  validation {
    condition     = can(cidrnetmask(var.address_space_network_hub))
    error_message = "Please specify a valid address space for the network hub."
  }
}

variable "address_space_gateway_subnet" {
  description = "Specifies the address space of the ExpressRoute gateway subnet. Recommended /27"
  type        = string
  sensitive   = false
  validation {
    condition     = can(cidrnetmask(var.address_space_gateway_subnet))
    error_message = "Please specify a valid address space for the network hub."
  }
}

variable "address_space_azfw_subnet" {
  description = "Specifies the address space of the Azure Firewall subnet. Recommended /26"
  type        = string
  sensitive   = false
  validation {
    condition     = can(cidrnetmask(var.address_space_azfw_subnet))
    error_message = "Please specify a valid address space for the Azure Firewall subnet."
  }
}

variable "address_space_azfw_management_subnet" {
  description = "Specifies the address space of the Azure Firewall Management subnet. Required for Basic SKU. Recommended /26"
  type        = string
  sensitive   = false
  default     = ""
  validation {
    condition     = var.address_space_azfw_management_subnet == "" || can(cidrnetmask(var.address_space_azfw_management_subnet))
    error_message = "Please specify a valid address space for the Azure Firewall Management subnet."
  }
}

variable "address_space_dns_inbound_subnet" {
  description = "Specifies the address space of the Azure Private DNS Resolver inbound endpoint."
  type        = string
  sensitive   = false
  validation {
    condition     = can(cidrnetmask(var.address_space_dns_inbound_subnet))
    error_message = "Please specify a valid address space for the network hub."
  }
}

variable "address_space_dns_outbound_subnet" {
  description = "Specifies the address space of the Azure Private DNS Resolver outbound endpoint."
  type        = string
  sensitive   = false
  validation {
    condition     = can(cidrnetmask(var.address_space_dns_outbound_subnet))
    error_message = "Please specify a valid address space for the network hub."
  }
}

variable "ergw_sku" {
  description = "Specifies the ExpressRoute Gateway SKU"
  type        = string
  sensitive   = false
  default     = "ErGw1AZ"
  validation {
    condition     = contains(["Basic", "Standard", "HighPerformance", "UltraPerformance", "ErGw1AZ", "ErGw2AZ", "ErGw3AZ"], var.ergw_sku)
    error_message = "Please use an allowed value: \"Basic\", \"Standard\", \"HighPerformance\", \"UltraPerformance\", \"ErGw1AZ\", \"ErGw2AZ\" or \"ErGw3AZ\"."
  }
}

variable "azfw_sku" {
  description = "Specifies the Azure Firewall SKU"
  type        = string
  sensitive   = false
  default     = "Standard"
  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.azfw_sku)
    error_message = "Please use an allowed value: \"Standard\", \"Premium\", \"Basic\"."
  }
}

variable "disable_bgp_route_propagation" {
  description = "Specifies whether the bgp route propagation should be disabled"
  type        = bool
  sensitive   = false
  nullable    = false
  default     = true
}

# File New Region variables
variable "storage_account_id" {
  description = "Specifies the resource ID of a storage account, where the log data should be stored."
  type        = string
  sensitive   = false
  validation {
    condition     = length(split("/", var.storage_account_id)) == 9
    error_message = "Please specify a valid resource ID."
  }
}

# File New Geo variables
variable "management_group_id" {
  description = "Specifies the management group resource id (Prod or Non-Prod)."
  type        = string
  sensitive   = false
  validation {
    condition     = length(split("/", var.management_group_id)) == 5
    error_message = "Please specify a management group id that consists of 5 segments (e.g. '/providers/Microsoft.Management/managementGroups/my-mg-name')."
  }
}

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
variable "private_dns_zone_ids" {
  description = "Specifies the ids of the central private dns zones."
  type = map(object({
    name                = string
    resource_group_name = string
    id                  = string
  }))
  sensitive = false
  validation {
    condition     = length([for key, value in var.private_dns_zone_ids : true if length(split("/", value.id)) != 9]) <= 0
    error_message = "Please specify valid resource IDs for the private dns zones."
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
