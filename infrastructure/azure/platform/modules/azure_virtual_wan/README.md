# Azure Virtual WAN Module for ADIA Multi-Region Architecture

This Terraform module implements Azure Virtual WAN to replace traditional hub and spoke architecture with a fully meshed, scalable, and secure network infrastructure.

## Architecture Overview

This module implements the ADIA multi-region architecture design with:

- **Azure Virtual WAN Standard SKU** for advanced features and secure hubs
- **Dual Virtual Hubs per Region** for Production and Non-Production isolation  
- **Full Mesh Connectivity** between all regions via Azure's global backbone
- **Secure Hubs** with Azure Firewall and Routing Intent
- **ExpressRoute Gateways** in each hub for on-premises connectivity
- **Global Network Manager Integration** for centralized policy enforcement

## Key Features

### 1. Multi-Region Full Mesh Connectivity
- All Virtual Hubs automatically interconnected via Azure's backbone
- Optimized any-to-any connectivity with minimal latency
- No need for manual peering configurations

### 2. Production/Non-Production Isolation
- Separate Virtual Hub per environment in each region
- Independent routing and security policies
- Clear separation for compliance and security

### 3. Secure Hub Capabilities
- Azure Firewall deployed in each Virtual Hub
- Routing Intent forces all traffic through firewall
- Support for both internet and private traffic inspection

### 4. Global Routing and Policy Control
- Virtual Hub route tables for custom routing
- Integration with Azure Virtual Network Manager
- Centralized security admin rules

## Usage Example

```hcl
module "virtual_wan" {
  source = "./modules/azure_virtual_wan"
  
  suffix              = "adia-prod"
  resource_group_name = "rg-network-vwan-prod"
  location           = "West Europe"
  
  tags = {
    Environment = "Production"
    Project     = "ADIA-Network"
    CostCenter  = "IT-Infrastructure"
  }
  
  # Define Virtual Hubs for each region/environment combination
  virtual_hubs = {
    "westeurope-prod" = {
      location                    = "westeurope"
      environment                = "prod"
      address_prefix             = "10.100.0.0/23"  # /23 for Virtual Hub
      enable_expressroute_gateway = true
      expressroute_scale_units   = 2
      enable_firewall           = true
      firewall_sku              = "Standard"
      enable_routing_intent     = true
    }
    "westeurope-dev" = {
      location                    = "westeurope"
      environment                = "dev"
      address_prefix             = "10.101.0.0/23"
      enable_expressroute_gateway = true
      expressroute_scale_units   = 1
      enable_firewall           = true
      firewall_sku              = "Basic"  # Cost optimization for dev
      enable_routing_intent     = true
    }
    "uaenorth-prod" = {
      location                    = "uaenorth"
      environment                = "prod"
      address_prefix             = "10.102.0.0/23"
      enable_expressroute_gateway = true
      expressroute_scale_units   = 2
      enable_firewall           = true
      firewall_sku              = "Standard"
      enable_routing_intent     = true
    }
    "uaenorth-dev" = {
      location                    = "uaenorth"
      environment                = "dev"
      address_prefix             = "10.103.0.0/23"
      enable_expressroute_gateway = true
      expressroute_scale_units   = 1
      enable_firewall           = true
      firewall_sku              = "Basic"
      enable_routing_intent     = true
    }
  }
  
  # Firewall policies per environment type
  firewall_policies = {
    "prod" = {
      location = "westeurope"
      sku     = "Standard"
    }
    "dev" = {
      location = "westeurope"
      sku     = "Basic"
    }
  }
}
```

## Migration from Traditional Hub-Spoke

### Key Differences

| Traditional Hub-Spoke | Virtual WAN |
|---------------------|-------------|
| Manual VNet peering | Automatic hub-to-hub connectivity |
| Regional firewalls in VNets | Secure hubs with integrated firewalls |
| Complex routing tables | Simplified routing via Virtual Hub router |
| Per-region ExpressRoute gateways | Integrated gateways in Virtual Hubs |
| Manual route propagation | Automatic route learning and propagation |

### Migration Steps

1. **Assess Current Architecture**
   - Document existing VNet peerings
   - Identify routing dependencies
   - Catalog ExpressRoute circuits

2. **Deploy Virtual WAN in Parallel**
   - Create Virtual WAN instance
   - Deploy Virtual Hubs per region/environment
   - Configure secure hubs with firewalls

3. **Migrate VNets Gradually**
   - Connect spoke VNets to Virtual Hubs
   - Update routing tables
   - Validate connectivity

4. **Migrate ExpressRoute Circuits**
   - Connect circuits to Virtual Hub gateways
   - Update on-premises routing
   - Remove old gateway dependencies

5. **Cleanup Traditional Infrastructure**
   - Remove manual peerings
   - Decommission old hub VNets
   - Clean up routing tables

## Network Addressing

### Recommended Address Allocation

- **Virtual Hub Address Space**: /23 per hub (provides ~500 IPs)
- **Production Hubs**: 10.100.x.0/23, 10.102.x.0/23, 10.104.x.0/23...
- **Non-Production Hubs**: 10.101.x.0/23, 10.103.x.0/23, 10.105.x.0/23...
- **Spoke VNets**: Use existing allocations, connect via hub connections

### Example Address Plan

```
Virtual WAN: ADIA-Production
├── West Europe Production Hub: 10.100.0.0/23
├── West Europe Development Hub: 10.101.0.0/23  
├── UAE North Production Hub: 10.102.0.0/23
├── UAE North Development Hub: 10.103.0.0/23
└── Future Region Hubs: 10.104.0.0/23+
```

## Security Considerations

### 1. Secure Hub Configuration
- Azure Firewall deployed in each hub
- Routing Intent enabled to force traffic inspection
- Threat intelligence and intrusion detection enabled

### 2. Environment Isolation
- Separate Virtual Hubs for Production/Non-Production
- Independent firewall policies per environment
- No direct Production-to-Non-Production connectivity

### 3. Network Segmentation
- Integration with Azure Virtual Network Manager
- Security Admin Rules for global policy enforcement
- Custom route tables for traffic control

## Cost Optimization

### Production Environments
- Standard SKU Azure Firewall for full feature set
- Higher ExpressRoute gateway scale units for performance
- Zone redundancy for high availability

### Non-Production Environments
- Basic SKU Azure Firewall for cost savings
- Lower scale units for ExpressRoute gateways
- Shared firewall policies where appropriate

## Monitoring and Diagnostics

### Built-in Capabilities
- Virtual Hub routing state monitoring
- Firewall logs and metrics
- Connection health monitoring
- ExpressRoute circuit monitoring

### Integration Points
- Azure Monitor for comprehensive monitoring
- Log Analytics for centralized logging
- Network Watcher for connectivity diagnostics
- Azure Sentinel for security monitoring

## Limitations and Considerations

### Current Limitations
- Maximum 100 Virtual Hubs per Virtual WAN
- Limited number of VNet connections per hub
- Some advanced routing scenarios require custom configuration

### Planning Considerations
- Virtual Hub address space cannot be changed after creation
- ExpressRoute circuit bandwidth limits
- Cross-region data transfer costs
- Firewall throughput requirements

## Resources

- [Azure Virtual WAN Documentation](https://docs.microsoft.com/en-us/azure/virtual-wan/)
- [Virtual WAN Architecture Guide](https://docs.microsoft.com/en-us/azure/virtual-wan/virtual-wan-global-transit-network-architecture)
- [Secure Virtual WAN](https://docs.microsoft.com/en-us/azure/virtual-wan/secure-cloud-network)
- [Virtual WAN Pricing](https://azure.microsoft.com/en-us/pricing/details/virtual-wan/)
