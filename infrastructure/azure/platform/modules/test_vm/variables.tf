# Variables for Test VM Module

variable "suffix" {
  description = "Suffix for resource names"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group for test resources"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "virtual_hub_ids" {
  description = "Map of Virtual Hub IDs by key (from Virtual WAN module)"
  type        = map(string)
}

variable "network_manager_spoke_group_id" {
  description = "ID of the Network Manager spoke VNets network group"
  type        = string
}

variable "admin_username" {
  description = "Admin username for the VMs"
  type        = string
  default     = "azureuser"
}

variable "vm_size" {
  description = "Size of the Virtual Machines"
  type        = string
  default     = "Standard_B1s"  # Very small size for testing - 1 vCPU, 1GB RAM
  
  validation {
    condition = contains([
      "Standard_B1ls",  # Cheapest: 1 vCPU, 0.5GB RAM
      "Standard_B1s",   # Small: 1 vCPU, 1GB RAM  
      "Standard_B1ms",  # Medium: 1 vCPU, 2GB RAM
      "Standard_B2s"    # Larger: 2 vCPU, 4GB RAM
    ], var.vm_size)
    error_message = "VM size must be one of the supported small VM sizes for testing."
  }
}

variable "enable_public_ips" {
  description = "Whether to create public IPs for VMs (for initial setup/troubleshooting)"
  type        = bool
  default     = false  # Set to true if you need external access for setup
}

variable "enable_network_watcher" {
  description = "Whether to enable Network Watcher for connectivity monitoring"
  type        = bool
  default     = true
}

variable "test_vms" {
  description = "Configuration for test VMs"
  type = map(object({
    location                   = string  # Azure region
    environment               = string  # Environment name (dev, prod, etc.)
    hub_key                   = string  # Key to identify which Virtual WAN hub to connect to
    vnet_address_space        = string  # Address space for the spoke VNet
    vm_subnet_address_prefix  = string  # Subnet for the VM within the VNet
  }))
  
  validation {
    condition = alltrue([
      for k, v in var.test_vms : can(cidrnetmask(v.vnet_address_space))
    ])
    error_message = "All VNet address spaces must be valid CIDR blocks."
  }
  
  validation {
    condition = alltrue([
      for k, v in var.test_vms : can(cidrnetmask(v.vm_subnet_address_prefix))
    ])
    error_message = "All VM subnet prefixes must be valid CIDR blocks."
  }
  
  # Example configuration:
  # test_vms = {
  #   "westeurope-vm" = {
  #     location                  = "westeurope"
  #     environment              = "dev"
  #     hub_key                  = "westeurope-dev"
  #     vnet_address_space       = "10.0.100.0/24"
  #     vm_subnet_address_prefix = "10.0.100.0/26"
  #   }
  #   "uaenorth-vm" = {
  #     location                  = "uaenorth"
  #     environment              = "dev" 
  #     hub_key                  = "uaenorth-dev"
  #     vnet_address_space       = "10.1.100.0/24"
  #     vm_subnet_address_prefix = "10.1.100.0/26"
  #   }
  # }
}
