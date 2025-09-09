# AWS Configuration for Tenant001
# ADIA Metropolis Multi-Cloud Platform

# Environment Configuration
environment         = "prod"
organization_name   = "adia"
suffix              = "AWS001"

# Regional Configuration
aws_regions = [
  "us-east-1",
  "us-west-2", 
  "eu-west-1"
]

# Transit Gateway Configuration
enable_cross_region_peering = true

transit_gateway_route_tables = {
  "production" = {
    name        = "adia-prod-production-rt"
    description = "Route table for production workloads"
    routes      = []
  }
  "shared" = {
    name        = "adia-prod-shared-rt"
    description = "Route table for shared services"
    routes      = []
  }
}

# AWS Organizations Configuration
create_organization = false  # Use existing AWS Organization

organizational_units = {
  # Platform OU (equivalent to Azure Platform Management Group)
  "platform" = {
    name   = "Platform"
    parent = "root"
  }
  # Management OU under Platform (equivalent to Azure Management MG)
  "management" = {
    name   = "Management"
    parent = "platform"
  }
  # Connectivity OU under Platform (equivalent to Azure Connectivity MG)
  "connectivity" = {
    name   = "Connectivity"
    parent = "platform"
  }
  # Landing Zones OU (equivalent to Azure Landing Zones MG)
  "landing-zones" = {
    name   = "Landing Zones"
    parent = "root"
  }
  # Playground OU (equivalent to Azure Playground MG)
  "playground" = {
    name   = "Playground"
    parent = "root"
  }
  # Decommissioned OU (equivalent to Azure Decommissioned MG)
  "decommissioned" = {
    name   = "Decommissioned"
    parent = "root"
  }
}

# Account Configuration (Empty - using existing AWS Organization accounts)
# Note: Add actual accounts here if you need to create new ones via Terraform
# Each account requires a unique, valid email address that your organization controls
aws_accounts = {
  # Example format (uncomment and update with real email addresses when needed):
  # "management-account" = {
  #   name  = "ADIA Management Account"
  #   email = "aws-management@your-actual-domain.com"  # Replace with real email
  #   ou    = "management"
  # }
}

# Network Configuration
vpc_cidr_blocks = {
  "us-east-1" = "10.100.0.0/16"
  "us-west-2" = "10.101.0.0/16"
  "eu-west-1" = "10.102.0.0/16"
}

# Security Configuration
security_group_rules = {
  "allow_https_from_azure" = {
    description = "Allow HTTPS traffic from Azure Virtual WAN"
    type        = "ingress"
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["10.0.0.0/8"] # Azure VWAN CIDR range
  }
  "allow_ssh_management" = {
    description = "Allow SSH from management networks"
    type        = "ingress" 
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["10.200.0.0/16"] # Management network
  }
}

# Compliance and Security
enable_aws_config = true

aws_config_rules = [
  "s3-bucket-public-access-prohibited",
  "ec2-security-group-attached-to-eni",
  "iam-password-policy",
  "root-access-key-check",
  "encrypted-volumes",
  "guardduty-enabled-centralized"
]

# GuardDuty Configuration
enable_guardduty = true

guardduty_settings = {
  finding_publishing_frequency = "FIFTEEN_MINUTES"
  datasources = {
    s3_logs = {
      enable = true
    }
    kubernetes = {
      audit_logs = {
        enable = true
      }
    }
    malware_protection = {
      scan_ec2_instance_with_findings = {
        ebs_volumes = {
          enable = true
        }
      }
    }
  }
}

# ================================================================
# AWS CLOUD WAN CONFIGURATION 
# ================================================================
# Core Network Name: ADIA-CloudWAN-Global
# Segment: SEGMENT_SHARED with isolateAttachments: false (flat network underlay)
# BGP ASN for AWS→Alkira peering: 64514 (anchor: tgw-uae-anchor, Peer ASN: 65002)

cloud_wan_config = {
  enabled = true
  
  # Core network name as per ADIA requirements
  core_network_name = "ADIA-CloudWAN-Global"
  
  # ADIA Regional Hubs - Anchor Regions + Incremental Stamps
  edge_locations = [
    # Anchor Regions
    {
      location = "eu-central-1"  # Frankfurt anchor
      asn      = 64512
      type     = "anchor"
      hub_name = "tgw-fra-anchor"
    },
    {
      location = "eu-west-1"     # Ireland anchor  
      asn      = 64513
      type     = "anchor"
      hub_name = "tgw-ire-anchor"
    },
    {
      location = "me-central-1"  # UAE anchor (BGP peering with Alkira)
      asn      = 64514
      type     = "anchor"
      hub_name = "tgw-uae-anchor"
      alkira_peering = {
        enabled      = true
        peer_asn     = 65002
        advertise_ranges = ["10.64.0.0/10"]  # AWS summarized range
        receive_ranges   = ["10.0.0.0/10"]   # Azure summarized range
      }
    },
    {
      location = "me-south-1"    # Bahrain anchor
      asn      = 64515
      type     = "anchor"
      hub_name = "tgw-bah-anchor"
    },
    # Incremental Stamps
    {
      location = "eu-west-2"     # London incremental
      asn      = 64516
      type     = "incremental"
      hub_name = "tgw-lon-incremental"
    },
    {
      location = "eu-west-3"     # Paris incremental
      asn      = 64517
      type     = "incremental"
      hub_name = "tgw-par-incremental"
    }
  ]
  
  # SEGMENTSHARED - Flat network underlay with no isolation
  network_segments = [
    {
      name                          = "SEGMENTSHARED"
      description                   = "ADIA shared segment - flat network underlay with no isolation"
      require_attachment_acceptance = false
      edge_locations               = ["eu-central-1", "eu-west-1", "me-central-1", "me-south-1", "eu-west-2", "eu-west-3"]
      isolate_attachments          = false  # Flat network underlay - no isolation
    }
  ]
  
  # Segment Actions - Route creation for Azure CIDR visibility
  segment_actions = [
    {
      action  = "create-route"
      segment = "SEGMENTSHARED"
      destination_cidr_blocks = ["10.0.0.0/8"]  # Ensures AWS sees Azure CIDRs
      mode    = "single-route"
    }
  ]
  
  # Internet Egress Configuration
  internet_egress = {
    segment                 = "SEGMENTSHARED"
    next_hop               = "ATTACHMENT_SECURITY_VPC_FRA"  # Palo Alto NGFW in Frankfurt anchor
    destination_cidr_blocks = ["0.0.0.0/0"]
    failover_enabled       = true
    failover_region        = "eu-west-1"  # Secondary anchor for redundancy
  }
  
  # Security VPC attachment configuration (for Palo Alto NGFW)
  security_vpc_attachments = {
    "security-vpc-fra" = {
      vpc_id      = "vpc-placeholder-fra"  # To be replaced with actual security VPC
      vpc_arn     = "arn:aws:ec2:eu-central-1:account:vpc/vpc-placeholder-fra"
      subnet_arns = ["arn:aws:ec2:eu-central-1:account:subnet/subnet-placeholder-fra"]
      segment     = "SEGMENTSHARED"
      environment = "security"
      region      = "eu-central-1"
      purpose     = "palo-alto-ngfw"
      attachment_name = "ATTACHMENT_SECURITY_VPC_FRA"
    }
  }
  
  # BGP and Routing Hygiene
  bgp_configuration = {
    aws_advertise_range = "10.64.0.0/10"  # AWS summarized range
    azure_receive_range = "10.0.0.0/10"   # Azure summarized range
    
    # Alkira peering configuration
    alkira_peering = {
      anchor_region = "me-central-1"  # tgw-uae-anchor
      aws_asn      = 64514
      peer_asn     = 65002
      enabled      = true
    }
  }
  
  # Route propagation and summarization
  route_summarization = {
    enabled = true
    aws_summary_routes = [
      {
        destination = "10.64.0.0/10"
        description = "AWS summarized range for Alkira advertisement"
      }
    ]
    azure_summary_routes = [
      {
        destination = "10.0.0.0/10" 
        description = "Azure summarized range received from Alkira"
      }
    ]
  }
  
  # Enable monitoring and flow logs
  enable_flow_logs = true
  log_retention_days = 30
  
  # Network analytics for global visibility
  enable_network_analytics = true
}
