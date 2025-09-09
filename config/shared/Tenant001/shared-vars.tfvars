# Shared Configuration for Cross-Cloud Modules
# ADIA Metropolis Multi-Cloud Platform - Tenant001

# ================================================================
# SHARED MODULES CONFIGURATION  
# ================================================================
# This file contains configuration for modules that are deployed 
# across both AWS and Azure platforms, controlled by pipeline checkboxes:
# - "Enable Azure Intent Layer (AVNM Security Admin Rules)"
# - "Enable AWS Intent Layer (Security Groups via AWS Firewall Manager)"

# ================================================================
# INTENT LAYER - CLOUD-AGNOSTIC SECURITY POLICIES
# ================================================================
# This section defines security intent that can be translated to 
# either Azure Virtual Network Manager Security Admin Rules or 
# AWS Security Groups via AWS Firewall Manager

intent_layer = {
  # Enable intent layer deployment for specific cloud providers
  enabled = true
  
  # Cloud provider selection (pipeline will override these)
  deploy_azure_intent = true   # Maps to Azure AVNM Security Admin Rules
  deploy_aws_intent   = true  # Maps to AWS Security Groups + Firewall Manager
  
  # Global Security Intent Rules (Cloud-Agnostic)
  # These rules will be translated to the appropriate cloud-specific resources
  security_rules = {
    
    # Block management ports from internet
    deny_management_ports_internet = {
      name        = "deny-mgmt-ports-internet"
      description = "Block SSH, RDP, and other management ports from internet"
      action      = "Deny"
      priority    = 200
      direction   = "Inbound"
      
      # Source configuration
      source = {
        type    = "ServiceTag"    # ServiceTag, IPPrefix, Any
        values  = ["Internet"]
      }
      
      # Destination configuration  
      destination = {
        type    = "Any"           # ServiceTag, IPPrefix, Any
        values  = ["*"]
      }
      
      # Protocol and ports
      protocol = "Tcp"
      ports = ["22", "3389", "5985", "5986", "1433", "3306", "5432"]
      
      # Cloud-specific mappings
      azure_mapping = {
        network_groups = ["spoke-vnets", "prod-vnets"]
        applies_to_vwan_hubs = false
      }
      
      aws_mapping = {
        policy_type = "SecurityGroup"
        resource_types = ["AWS::EC2::SecurityGroup"]
        target_organizational_units = ["ou-prod", "ou-nonprod"]
        target_ou_ids = ["ou-prod", "ou-nonprod"]
        vpc_tags = {
          Environment = ["prod", "dev", "staging"]
        }
        apply_to_all_vpcs = false
        source_sg_tags = {}
        destination_sg_tags = {}
      }
    }
    
    # Deny prod-to-nonprod lateral movement
    deny_prod_nonprod_lateral = {
      name        = "deny-prod-nonprod-isolation"
      description = "Block lateral movement between prod and non-prod environments"
      action      = "Deny"
      priority    = 250
      direction   = "Inbound"
      
      source = {
        type   = "NetworkGroup"
        values = ["prod-network-group"]
      }
      
      destination = {
        type   = "NetworkGroup" 
        values = ["nonprod-network-group"]
      }
      
      protocol = "Any"
      ports    = ["*"]
      
      azure_mapping = {
        network_groups = ["prod-vnets", "nonprod-vnets"]
        bidirectional = true
      }
      
      aws_mapping = {
        policy_type = "SecurityGroup"
        resource_types = ["AWS::EC2::SecurityGroup"]
        target_organizational_units = []
        target_ou_ids = []
        apply_to_all_vpcs = false
        source_sg_tags = {
          Environment = ["prod"]
        }
        destination_sg_tags = {
          Environment = ["dev", "staging", "test"]  
        }
        vpc_tags = {}
      }
    }
    
    # Allow specific application traffic
    allow_web_traffic = {
      name        = "allow-web-traffic"
      description = "Allow standard web traffic (HTTP/HTTPS)"
      action      = "Allow"
      priority    = 310
      direction   = "Inbound"
      
      source = {
        type   = "ServiceTag"
        values = ["Internet"]
      }
      
      destination = {
        type   = "ServiceTag"
        values = ["VirtualNetwork"]
      }
      
      protocol = "Tcp"
      ports    = ["80", "443"]
      
      azure_mapping = {
        network_groups = ["spoke-vnets"]
        applies_to_dmz_only = true
      }
      
      aws_mapping = {
        policy_type = "SecurityGroup"
        resource_types = ["AWS::EC2::SecurityGroup"]
        target_organizational_units = []
        target_ou_ids = []
        apply_to_all_vpcs = false
        source_sg_tags = {}
        destination_sg_tags = {}
        vpc_tags = {
          Tier = ["web", "dmz"]
        }
      }
    }
    
    # Block outbound to high-risk regions
    deny_outbound_high_risk_regions = {
      name        = "deny-outbound-high-risk"
      description = "Block outbound traffic to high-risk geographical regions"
      action      = "Deny"
      priority    = 320
      direction   = "Outbound"
      
      source = {
        type   = "Any"
        values = ["*"]
      }
      
      destination = {
        type   = "IPPrefix"
        values = [
          # Example high-risk CIDR blocks - customize as needed
          "185.0.0.0/8",    # Known malicious ranges
          "91.0.0.0/8"      # Adjust based on security policy
        ]
      }
      
      protocol = "Any"
      ports    = ["*"]
      
      azure_mapping = {
        network_groups = ["all-vnets"]
        applies_to_vwan_hubs = true
      }
      
      aws_mapping = {
        policy_type = "SecurityGroup"
        resource_types = ["AWS::EC2::SecurityGroup"]
        target_organizational_units = []
        target_ou_ids = []
        apply_to_all_vpcs = true
        source_sg_tags = {}
        destination_sg_tags = {}
        vpc_tags = {}
      }
    }

    # ================================================================
    # TEST INFRASTRUCTURE CONNECTIVITY RULES - TiP (Test Infrastructure Provisioning)
    # ================================================================
    
    # Allow SSH between test VMs for remote testing
    allow_test_vm_ssh = {
      name        = "allow-test-vm-ssh"
      description = "Allow SSH between test VMs for cross-region remote connectivity testing"
      action      = "Allow"
      priority    = 262
      direction   = "Inbound"
      
      source = {
        type   = "IPPrefix"
        values = [
          "10.100.0.0/24",  # West Europe test VMs
          "10.101.0.0/24"   # UAE North test VMs
        ]
      }
      
      destination = {
        type   = "IPPrefix"
        values = [
          "10.100.0.0/24",  # West Europe test VMs
          "10.101.0.0/24"   # UAE North test VMs
        ]
      }
      
      protocol = "Tcp"
      ports    = ["22"]
      
      azure_mapping = {
        network_groups = ["nonprod-network-group", "spoke-vnets-network-group"]
        applies_to_test_infrastructure = true
        conditional_deployment = true
      }
      
      aws_mapping = {
        policy_type = "SecurityGroup"
        resource_types = ["AWS::EC2::SecurityGroup"]
        target_organizational_units = []
        target_ou_ids = []
        apply_to_all_vpcs = false
        source_sg_tags = {}
        destination_sg_tags = {}
        vpc_tags = {
          Component = ["Test-Infrastructure"]
        }
      }
    }
    
    # Allow HTTP/HTTPS for web connectivity testing
    allow_test_vm_web = {
      name        = "allow-test-vm-web"
      description = "Allow HTTP/HTTPS between test VMs for cross-region web connectivity testing"
      action      = "Allow"
      priority    = 263
      direction   = "Inbound"
      
      source = {
        type   = "IPPrefix"
        values = [
          "10.100.0.0/24",  # West Europe test VMs
          "10.101.0.0/24"   # UAE North test VMs
        ]
      }
      
      destination = {
        type   = "IPPrefix"
        values = [
          "10.100.0.0/24",  # West Europe test VMs
          "10.101.0.0/24"   # UAE North test VMs
        ]
      }
      
      protocol = "Tcp"
      ports    = ["80", "443", "8080"]
      
      azure_mapping = {
        network_groups = ["nonprod-network-group", "spoke-vnets-network-group"]
        applies_to_test_infrastructure = true
        conditional_deployment = true
      }
      
      aws_mapping = {
        policy_type = "SecurityGroup"
        resource_types = ["AWS::EC2::SecurityGroup"]
        target_organizational_units = []
        target_ou_ids = []
        apply_to_all_vpcs = false
        source_sg_tags = {}
        destination_sg_tags = {}
        vpc_tags = {
          Component = ["Test-Infrastructure"]
        }
      }
    }
    
    # Allow iperf3 performance testing between test VMs
    allow_test_vm_iperf3 = {
      name        = "allow-test-vm-iperf3"
      description = "Allow iperf3 performance testing between test VMs across regions"
      action      = "Allow"
      priority    = 265
      direction   = "Inbound"
      
      source = {
        type   = "IPPrefix"
        values = [
          "10.100.0.0/24",  # West Europe test VMs
          "10.101.0.0/24"   # UAE North test VMs
        ]
      }
      
      destination = {
        type   = "IPPrefix"
        values = [
          "10.100.0.0/24",  # West Europe test VMs
          "10.101.0.0/24"   # UAE North test VMs
        ]
      }
      
      protocol = "Tcp"
      ports    = ["5201"]
      
      azure_mapping = {
        network_groups = ["nonprod-network-group"]
        applies_to_test_infrastructure = true
        conditional_deployment = true
      }
      
      aws_mapping = {
        policy_type = "SecurityGroup"
        resource_types = ["AWS::EC2::SecurityGroup"]
        target_organizational_units = []
        target_ou_ids = []
        apply_to_all_vpcs = false
        source_sg_tags = {}
        destination_sg_tags = {}
        vpc_tags = {
          Component = ["Test-Infrastructure"]
        }
      }
    }
    
    # Allow test VMs to reach internet for updates and Azure services
    allow_test_vm_internet_outbound = {
      name        = "allow-test-vm-internet-outbound"
      description = "Allow test VMs to reach internet for updates and Azure services"
      action      = "Allow"
      priority    = 264
      direction   = "Outbound"
      
      source = {
        type   = "IPPrefix"
        values = [
          "10.100.0.0/24",  # West Europe test VMs
          "10.101.0.0/24"   # UAE North test VMs
        ]
      }
      
      destination = {
        type   = "ServiceTag"
        values = ["Internet"]
      }
      
      protocol = "Any"
      ports    = ["*"]
      
      azure_mapping = {
        network_groups = ["nonprod-network-group"]
        applies_to_test_infrastructure = true
        conditional_deployment = true
      }
      
      aws_mapping = {
        policy_type = "SecurityGroup"
        resource_types = ["AWS::EC2::SecurityGroup"]
        target_organizational_units = []
        target_ou_ids = []
        apply_to_all_vpcs = false
        source_sg_tags = {}
        destination_sg_tags = {}
        vpc_tags = {
          Component = ["Test-Infrastructure"]
        }
      }
    }
  }
  
  # Network Group Definitions (for Azure AVNM)
  azure_network_groups = {
    prod_vnets = {
      name        = "prod-network-group"
      description = "Production VNets network group"
      member_type = "VirtualNetwork"
      
      # Dynamic membership criteria
      conditions = [
        {
          field    = "tags.Environment"
          operator = "Equals"
          values   = ["prod", "production"]
        }
      ]
    }
    
    nonprod_vnets = {
      name        = "nonprod-network-group" 
      description = "Non-production VNets network group"
      member_type = "VirtualNetwork"
      
      conditions = [
        {
          field    = "tags.Environment" 
          operator = "In"
          values   = ["dev", "staging", "test", "uat"]
        }
      ]
    }
    
    spoke_vnets = {
      name        = "spoke-vnets-network-group"
      description = "All spoke VNets network group"
      member_type = "VirtualNetwork"
      
      conditions = [
        {
          field    = "name"
          operator = "Contains"
          values   = ["spoke", "workload"]
        }
      ]
    }
  }
  
  # AWS-specific configuration
  aws_config = {
    firewall_manager_policy_name = "ADIA-Global-AWS-Segmentation-Policy"
    
    # AWS Organizations configuration - ADIA OU targeting
    target_organizational_units = [
      "platform",      # Platform OU (Management, Connectivity)
      "landing-zones", # Landing Zones OU (Production, Development)
      "playground"     # Playground OU
    ]
    
    # Security Group tagging strategy
    security_group_tags = {
      ManagedBy = "ADIA-Intent-Layer"
      Source    = "Cloud-Agnostic-Policy"
      FWMPolicy = "ADIA-Global-AWS-Segmentation-Policy"
    }
    
    # AWS Firewall Manager configuration per ADIA requirements
    firewall_manager_config = {
      # Audit & auto-remediate public exposure
      audit_rules = [
        "ssh-public-exposure",      # SSH (port 22)
        "rdp-public-exposure",      # RDP (port 3389)
        "database-public-exposure", # DB ports (1433, 3306, 5432)
        "telnet-ftp-http-exposure", # Legacy protocols
        "management-ports-exposure" # Management ports (5985, 5986)
      ]
      
      auto_remediation_enabled = true
      compliance_notifications = true
      
      # Security policy enforcement
      policy_enforcement_level = "audit"  # Can be "audit" or "enforce"
      
      # Excluded accounts (if any)
      excluded_accounts = []
      
      # Additional WAF and Shield policies
      enable_waf_policies    = true
      enable_shield_policies = true
    }
    
    # Service Control Policies (SCPs) configuration
    service_control_policies = {
      deny_prod_nonprod_policy = {
        name        = "Deny-Prod-to-NonProd-Actions"
        description = "Blocks lateral movement between Production and Non-Production environments"
        
        # Blocked actions for prod-to-nonprod isolation
        blocked_actions = [
          "ec2:AuthorizeSecurityGroupIngress",  # Prevents public SSH/RDP
          "ec2:CreateVpcPeeringConnection",     # Prevents Prod/NonProd peering
          "ec2:AcceptVpcPeeringConnection",
          "ec2:CreateTransitGatewayPeeringAttachment",
          "ec2:AcceptTransitGatewayPeeringAttachment"
        ]
        
        # Target OUs for policy application
        target_ous = ["platform", "landing-zones"]
        
        # Conditions for when policy applies
        conditions = {
          source_environment      = "prod"
          destination_environment = ["dev", "staging", "test", "nonprod"]
        }
      }
    }
  }
}

# ================================================================
# FUTURE SHARED MODULES
# ================================================================
# Additional shared modules can be added here such as:
# - Cross-cloud DNS configuration
# - Multi-cloud monitoring setup  
# - Federated identity configuration
# - Cross-cloud backup policies
# - Unified cost management
# - Cross-platform compliance reporting
