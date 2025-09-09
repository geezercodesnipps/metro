# Outputs for Test VM Module

# VM Information
output "test_vms" {
  description = "Information about all test VMs"
  value = {
    for k, vm in azurerm_linux_virtual_machine.test_vms : k => {
      id              = vm.id
      name            = vm.name
      resource_group  = vm.resource_group_name
      location        = vm.location
      private_ip      = vm.private_ip_address
      admin_username  = vm.admin_username
      computer_name   = vm.computer_name
      size           = vm.size
    }
  }
}

# Public IP Information (if enabled)
output "public_ips" {
  description = "Public IP addresses for test VMs (if enabled)"
  value = var.enable_public_ips ? {
    for k, pip in azurerm_public_ip.vm_public_ips : k => {
      ip_address    = pip.ip_address
      fqdn         = pip.fqdn
      vm_name      = azurerm_linux_virtual_machine.test_vms[k].name
    }
  } : {}
}

# Virtual Network Information
output "spoke_vnets" {
  description = "Information about spoke VNets created for test VMs"
  value = {
    for k, vnet in azurerm_virtual_network.spoke_vnets : k => {
      id                = vnet.id
      name              = vnet.name
      resource_group    = vnet.resource_group_name
      location          = vnet.location
      address_space     = vnet.address_space
      vm_subnet_id      = azurerm_subnet.vm_subnets[k].id
      vm_subnet_prefix  = length(azurerm_subnet.vm_subnets[k].address_prefixes) > 0 ? azurerm_subnet.vm_subnets[k].address_prefixes[0] : null
    }
  }
}

# Virtual Hub Connections
output "vwan_connections" {
  description = "Virtual WAN hub connections for spoke VNets"
  value = {
    for k, conn in azurerm_virtual_hub_connection.spoke_connections : k => {
      id            = conn.id
      name          = conn.name
      hub_id        = conn.virtual_hub_id
      vnet_id       = conn.remote_virtual_network_id
      routing_weight = try(conn.routing[0].static_vnet_route[0].address_prefixes, null)
    }
  }
}

# Network Security Groups
output "network_security_groups" {
  description = "Network Security Groups for VM subnets"
  value = {
    for k, nsg in azurerm_network_security_group.vm_nsgs : k => {
      id    = nsg.id
      name  = nsg.name
      location = nsg.location
      rules = [
        for rule in nsg.security_rule : {
          name                       = rule.name
          priority                   = rule.priority
          direction                  = rule.direction
          access                     = rule.access
          protocol                   = rule.protocol
          source_port_range         = rule.source_port_range
          destination_port_range    = rule.destination_port_range
          source_address_prefix     = rule.source_address_prefix
          destination_address_prefix = rule.destination_address_prefix
        }
      ]
    }
  }
}

# VM Password Information (for reference - values are sensitive)
output "vm_password_info" {
  description = "Information about VM passwords (values not exposed for security)"
  value = {
    for k, vm in azurerm_linux_virtual_machine.test_vms : k => {
      vm_name        = vm.name
      admin_username = vm.admin_username
      password_set   = true
      note          = "Password is randomly generated - use Azure console or reset if needed"
    }
  }
  sensitive = false
}

# Connectivity Test Commands
output "connectivity_test_commands" {
  description = "Useful commands for testing connectivity between VMs"
  value = {
    ssh_connections = var.enable_public_ips ? {
      for k, vm in azurerm_linux_virtual_machine.test_vms : k => 
        "ssh ${vm.admin_username}@${azurerm_public_ip.vm_public_ips[k].ip_address}"
    } : {}
    
    ping_tests = {
      for src_key, src_vm in azurerm_linux_virtual_machine.test_vms : 
        "${src_key}_ping_tests" => [
          for dst_key, dst_vm in azurerm_linux_virtual_machine.test_vms : 
            "ping -c 4 ${dst_vm.private_ip_address}  # From ${src_key} to ${dst_key}"
          if src_key != dst_key
        ]
    }
    
    network_trace_commands = var.enable_network_watcher ? {
      for k, vm in azurerm_linux_virtual_machine.test_vms : 
        "${k}_network_trace" => "az network watcher packet-capture create --resource-group ${vm.resource_group_name} --vm ${vm.name} --name ${vm.name}-trace --storage-account <storage_account_name>"
    } : {}
  }
}

# Resource Summary
output "resource_summary" {
  description = "Summary of all resources created by this module"
  value = {
    total_vms               = length(azurerm_linux_virtual_machine.test_vms)
    total_vnets            = length(azurerm_virtual_network.spoke_vnets)
    total_vwan_connections = length(azurerm_virtual_hub_connection.spoke_connections)
    total_nsgs             = length(azurerm_network_security_group.vm_nsgs)
    public_ips_enabled     = var.enable_public_ips
    network_watcher_enabled = var.enable_network_watcher
    
    vm_locations = [
      for k, vm in azurerm_linux_virtual_machine.test_vms : vm.location
    ]
    
    address_spaces = [
      for k, vnet in azurerm_virtual_network.spoke_vnets : tolist(vnet.address_space)[0]
    ]
  }
}
