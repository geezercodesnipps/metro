# Intent Layer Module

This module provides a **cloud-agnostic security policy abstraction layer** that translates unified security intent into provider-specific implementations.

## Overview

The Intent Layer allows you to define security policies once and deploy them across multiple cloud providers:

- **Azure**: Implements rules using Azure Virtual Network Manager (AVNM) Security Admin Rules
- **AWS**: Implements rules using AWS Security Groups and AWS Firewall Manager

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    INTENT LAYER                             │
├─────────────────────────────────────────────────────────────┤
│  Cloud-Agnostic Security Intent Definition                  │
│  • Common rule format                                       │
│  • Provider-neutral syntax                                  │
│  • Unified policy management                                │
└─────────────────┬───────────────────────────────────────────┘
                  │
        ┌─────────┴─────────┐
        │                   │
        ▼                   ▼
┌─────────────┐    ┌─────────────────┐
│   AZURE     │    │      AWS        │
│   AVNM      │    │  Security Groups│
│ Security    │    │      +          │
│ Admin Rules │    │ Firewall Mgr    │
└─────────────┘    └─────────────────┘
```

## Features

### 🎯 **Unified Policy Definition**
- Single source of truth for security policies
- Cloud-agnostic rule syntax
- Consistent policy enforcement across clouds

### 🔄 **Multi-Cloud Translation**
- **Azure**: AVNM Security Admin Rules with Network Groups
- **AWS**: Security Groups with Firewall Manager centralization
- Automatic protocol and port mapping

### 📊 **Policy Types Supported**
- **Management Access Control**: Block SSH/RDP from internet
- **Environment Isolation**: Prevent prod-to-nonprod lateral movement  
- **Application Traffic**: Allow specific web traffic patterns
- **Geographic Restrictions**: Block traffic to high-risk regions

## Usage

### Basic Configuration

```hcl
module "intent_layer" {
  source = "./modules/intent_layer"
  
  # Enable cloud providers
  enable_azure_intent = var.deploy_azure_intent
  enable_aws_intent   = var.deploy_aws_intent
  
  # Azure configuration
  azure_network_manager_id = var.network_manager_id
  
  # Intent rules
  intent_rules = var.intent_layer.security_rules
  azure_network_groups = var.intent_layer.azure_network_groups
  aws_config = var.intent_layer.aws_config
  
  suffix               = var.suffix
  location            = var.location
  resource_group_name = var.resource_group_name
  tags               = var.tags
}
```

### Intent Rule Definition

```hcl
intent_rules = {
  deny_management_ports = {
    name        = "deny-mgmt-ports-internet"
    description = "Block management ports from internet"
    action      = "Deny"
    priority    = 100
    direction   = "Inbound"
    protocol    = "Tcp"
    ports       = ["22", "3389", "5985", "5986"]
    
    source = {
      type   = "ServiceTag"
      values = ["Internet"]
    }
    
    destination = {
      type   = "Any"
      values = ["*"]
    }
    
    # Azure-specific configuration
    azure_mapping = {
      network_groups = ["spoke-vnets", "prod-vnets"]
    }
    
    # AWS-specific configuration  
    aws_mapping = {
      vpc_tags = {
        Environment = ["prod", "dev"]
      }
    }
  }
}
```

## Pipeline Integration

The module integrates with Azure DevOps pipelines through checkbox parameters:

```yaml
parameters:
  - name: enableAzureIntent
    displayName: 'Enable Azure Intent Layer (AVNM)'
    type: boolean
    default: true
    
  - name: enableAwsIntent
    displayName: 'Enable AWS Intent Layer (Security Groups)'
    type: boolean
    default: false
```

## Azure Implementation Details

### Network Manager Security Admin Rules
- Creates Security Admin Configuration
- Implements rule collections with intent-based rules
- Supports dynamic network group membership
- Automatic protocol translation (Any → *)

### Network Groups
- Dynamic membership based on tags
- Support for VNet and Subnet scoping
- Integration with existing AVNM infrastructure

## AWS Implementation Details

### Security Groups + Firewall Manager
- Creates centralized security groups per intent rule
- Implements ingress/egress rules based on direction
- Uses Firewall Manager for organization-wide enforcement
- Supports organizational unit targeting

## Rule Translation Examples

| Intent Definition | Azure AVNM | AWS Security Group |
|------------------|-------------|-------------------|
| `protocol = "Any"` | `protocol = "*"` | `protocol = "-1"` |
| `ports = ["*"]` | `destination_port_ranges = ["0-65535"]` | `from_port = 0, to_port = 65535` |
| `source.type = "ServiceTag"` | `address_prefix_type = "ServiceTag"` | `cidr_blocks = ["0.0.0.0/0"]` |
| `action = "Deny"` | `action = "Deny"` | No rule created (default deny) |

## Prerequisites

### Azure
- Azure Network Manager deployed and configured
- Appropriate RBAC permissions for Security Admin Rules
- Management Group or Subscription scope

### AWS  
- AWS Firewall Manager enabled in organization
- Security account with appropriate permissions
- AWS Organizations configured

## Outputs

The module provides comprehensive outputs for both cloud providers:

```hcl
# Azure outputs
azure_security_admin_configuration_id
azure_network_group_ids
azure_admin_rule_collection_id

# AWS outputs  
aws_security_group_ids
aws_firewall_manager_policy_id

# Summary
intent_layer_summary
```

## Best Practices

### 1. **Priority Management**
- Use priority ranges: 100-199 (high), 200-299 (medium), 300+ (low)
- Leave gaps for future rule insertion

### 2. **Network Group Strategy**
- Use dynamic membership with tags
- Align with existing tagging strategy
- Consider hierarchy: env → tier → app

### 3. **Rule Testing**
- Test rules in non-production first
- Use allow rules sparingly (default deny principle)
- Monitor rule hit counts and effectiveness

### 4. **Multi-Cloud Considerations**
- Keep intent rules cloud-agnostic
- Use provider-specific mappings for fine-tuning
- Maintain consistent security posture across clouds

## Troubleshooting

### Azure AVNM Issues
- Verify Network Manager scope and permissions
- Check rule priority conflicts
- Ensure network groups have members
- **NetworkGroup References**: Intent rules with `source.type = "NetworkGroup"` or `destination.type = "NetworkGroup"` are currently skipped because Azure AVNM Security Admin Rules don't support direct NetworkGroup references in address prefixes. Convert these to IP-based rules or implement using connectivity configurations.

### AWS Issues
- Verify Firewall Manager permissions
- Check organizational unit membership
- Validate security group limits

### Known Limitations
- **Azure NetworkGroup Rules**: Rules like `deny_prod_nonprod_lateral` that use NetworkGroup types in source/destination are not currently supported in Azure AVNM implementation
- **Workarounds**: 
  - Convert NetworkGroup rules to use specific IP ranges (`source.type = "IPPrefix"`)
  - Use Azure Network Manager connectivity configurations for network isolation
  - Implement network-to-network isolation at the NSG level instead

## Roadmap

- [ ] Support for Azure Application Security Groups
- [ ] AWS Network ACL integration  
- [ ] GCP VPC Firewall Rules support
- [ ] Policy drift detection and remediation
- [ ] Terraform state drift monitoring
