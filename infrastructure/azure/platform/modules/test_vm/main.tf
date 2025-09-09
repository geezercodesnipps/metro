# Test VM Module for Virtual WAN Connectivity Testing
# Deploys small Linux VMs in spoke VNets connected to Virtual WAN hubs

# Random password for VM admin user
resource "random_password" "vm_password" {
  for_each = var.test_vms
  
  length  = 16
  special = true
}

# Local values for VM passwords (no Key Vault dependency)
locals {
  vm_passwords = {
    for k, v in var.test_vms : k => random_password.vm_password[k].result
  }
}

# Spoke VNet for each test VM
resource "azurerm_virtual_network" "spoke_vnets" {
  for_each = var.test_vms
  
  name                = "vnet-spoke-${each.key}-${var.suffix}"
  address_space       = [each.value.vnet_address_space]
  location            = each.value.location
  resource_group_name = var.resource_group_name
  
  tags = merge(var.tags, {
    Environment = each.value.environment
    Purpose     = "Virtual WAN Testing"
    Region      = each.value.location
  })
}

# VM subnet within each spoke VNet
resource "azurerm_subnet" "vm_subnets" {
  for_each = var.test_vms
  
  name                 = "snet-vm-${each.key}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke_vnets[each.key].name
  address_prefixes     = [each.value.vm_subnet_address_prefix]
}

# Network Security Group for test VMs
resource "azurerm_network_security_group" "vm_nsgs" {
  for_each = var.test_vms
  
  name                = "nsg-vm-${each.key}-${var.suffix}"
  location            = each.value.location
  resource_group_name = var.resource_group_name
  
  # Allow SSH from Virtual Network (for testing connectivity)
  security_rule {
    name                       = "Allow-SSH-VNet"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
  
  # Allow ICMP for ping testing
  security_rule {
    name                       = "Allow-ICMP-VNet"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }
  
  # Allow outbound connectivity
  security_rule {
    name                       = "Allow-Outbound"
    priority                   = 1003
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  
  tags = merge(var.tags, {
    Environment = each.value.environment
    Purpose     = "Virtual WAN Testing"
  })
}

# Associate NSG with VM subnet
resource "azurerm_subnet_network_security_group_association" "vm_nsg_associations" {
  for_each = var.test_vms
  
  subnet_id                 = azurerm_subnet.vm_subnets[each.key].id
  network_security_group_id = azurerm_network_security_group.vm_nsgs[each.key].id
}

# Public IP for VM (optional, for initial setup)
resource "azurerm_public_ip" "vm_public_ips" {
  for_each = var.enable_public_ips ? var.test_vms : {}
  
  name                = "pip-vm-${each.key}-${var.suffix}"
  location            = each.value.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  
  tags = merge(var.tags, {
    Environment = each.value.environment
    Purpose     = "Virtual WAN Testing"
  })
}

# Network Interface for each VM
resource "azurerm_network_interface" "vm_nics" {
  for_each = var.test_vms
  
  name                = "nic-vm-${each.key}-${var.suffix}"
  location            = each.value.location
  resource_group_name = var.resource_group_name
  
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm_subnets[each.key].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.enable_public_ips ? azurerm_public_ip.vm_public_ips[each.key].id : null
  }
  
  tags = merge(var.tags, {
    Environment = each.value.environment
    Purpose     = "Virtual WAN Testing"
  })
}

# Linux Virtual Machines
resource "azurerm_linux_virtual_machine" "test_vms" {
  for_each = var.test_vms
  
  name                = "vm-${each.key}-${var.suffix}"
  location            = each.value.location
  resource_group_name = var.resource_group_name
  size                = var.vm_size
  admin_username      = var.admin_username
  
  # Disable password authentication and use SSH keys for better security
  disable_password_authentication = false
  
  network_interface_ids = [
    azurerm_network_interface.vm_nics[each.key].id,
  ]
  
  admin_password = random_password.vm_password[each.key].result
  
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"  # Small premium disk for better performance
  }
  
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
  
  # Install network tools for connectivity testing
  custom_data = base64encode(templatefile("${path.module}/cloud-init.yml", {
    admin_username = var.admin_username
  }))
  
  tags = merge(var.tags, {
    Environment = each.value.environment
    Purpose     = "Virtual WAN Testing"
    Region      = each.value.location
  })
  
  depends_on = [azurerm_network_interface.vm_nics]
}

# Connect spoke VNets to Virtual WAN hubs
resource "azurerm_virtual_hub_connection" "spoke_connections" {
  for_each = var.test_vms
  
  name                      = "conn-spoke-${each.key}-${var.suffix}"
  virtual_hub_id            = var.virtual_hub_ids[each.value.hub_key]
  remote_virtual_network_id = azurerm_virtual_network.spoke_vnets[each.key].id
  
  # Enable internet security through the hub firewall
  internet_security_enabled = true
  
  depends_on = [
    azurerm_virtual_network.spoke_vnets,
    azurerm_linux_virtual_machine.test_vms
  ]
}

# Add spoke VNets to the Network Manager's spoke network group
resource "azurerm_network_manager_static_member" "spoke_vnet_members" {
  for_each = var.test_vms
  
  name                = "member-${each.key}-${var.suffix}"
  network_group_id    = var.network_manager_spoke_group_id
  target_virtual_network_id = azurerm_virtual_network.spoke_vnets[each.key].id
  
  depends_on = [
    azurerm_virtual_network.spoke_vnets
  ]
}

# Network Watcher for connectivity testing (optional)
resource "azurerm_network_watcher" "connectivity_monitor" {
  for_each = var.enable_network_watcher ? toset(distinct([for k, v in var.test_vms : v.location])) : toset([])
  
  name                = "nw-${each.key}-${var.suffix}"
  location            = each.key
  resource_group_name = var.resource_group_name
  
  tags = merge(var.tags, {
    Purpose = "Virtual WAN Testing"
  })
}
