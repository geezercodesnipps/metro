# Geo Region Mapping Management

This directory contains PowerShell scripts for managing the `geo_region_mapping` configuration in Terraform vars files. These scripts are designed to work with Azure DevOps pipelines and provide functionality to add or remove geographic regions and their associated Azure regions.

## Files Overview

- **`Manage-GeoRegionMapping.ps1`** - Main script for managing geo region mappings
- **`Find-EmptySubscriptions.ps1`** - Utility script for discovering empty Azure subscriptions
- **`azure-pipelines-geo-management.yml`** - Multi-stage Azure DevOps pipeline with dropdown parameters
- **`Test-GeoRegionMapping.ps1`** - Test script for local validation
- **`README-GeoRegionMapping.md`** - This documentation file

## Supported Operations

### Geographic Regions (Geos)
- **EMEA**: Europe, Middle East, and Africa
  - Regions: `northeurope`, `westeurope`
  - Default platform location: `westeurope`
- **UAE**: United Arab Emirates  
  - Regions: `uaenorth`, `uaesouth`
  - Default platform location: `uaenorth`

### Available Actions
1. **AddGeo** - Add a complete new geographic region
2. **RemoveGeo** - Remove an entire geographic region and all its regions
3. **AddRegion** - Add a specific Azure region to an existing geo
4. **RemoveRegion** - Remove a specific Azure region from a geo

## Script Usage

### Command Line Usage

```powershell
# Add a new region to existing geo
.\Manage-GeoRegionMapping.ps1 -Action "AddRegion" -VarsFilePath "config/Tenant001/vars.tfvars" -GeoName "UAE" -RegionName "uaesouth" -RegionSubscriptionId "your-subscription-id"

# Remove a region from geo
.\Manage-GeoRegionMapping.ps1 -Action "RemoveRegion" -VarsFilePath "config/Tenant001/vars.tfvars" -GeoName "EMEA" -RegionName "northeurope"

# Add a new geo (will be empty initially)
.\Manage-GeoRegionMapping.ps1 -Action "AddGeo" -VarsFilePath "config/Tenant001/vars.tfvars" -GeoName "UAE" -GeoPlatformSubscriptionId "your-platform-sub-id" -GeoPlatformLocation "uaenorth"

# Remove entire geo
.\Manage-GeoRegionMapping.ps1 -Action "RemoveGeo" -VarsFilePath "config/Tenant001/vars.tfvars" -GeoName "UAE"
```

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `Action` | Yes | `AddGeo`, `RemoveGeo`, `AddRegion`, `RemoveRegion` |
| `VarsFilePath` | Yes | Path to the Terraform vars file |
| `GeoName` | Yes | Geographic region name (`EMEA`, `UAE`) |
| `RegionName` | Conditional | Azure region name (required for region operations) |
| `GeoPlatformSubscriptionId` | Conditional | Platform subscription ID (required for `AddGeo`) |
| `GeoPlatformLocation` | Optional | Platform location (uses default if not provided) |
| `RegionSubscriptionId` | Conditional | Region subscription ID (required for `AddRegion`) |
| `Environment` | Optional | Environment name (default: `dev`) |

## Azure DevOps Pipeline

### Pipeline Features

The Azure DevOps pipeline (`azure-pipelines-geo-management.yml`) provides a **multi-stage approach** with:

#### Stage 1: Parameter Validation
- **Interactive Parameters** - Dropdown selections for all options
- **Parameter Validation** - Validates required parameters based on action
- **Geo-Region Combination Validation** - Ensures valid region selections

#### Stage 2: Empty Subscription Discovery (Optional)
- **Dynamic Subscription Detection** - Automatically finds empty subscriptions in tenant
- **Resource Validation** - Checks subscriptions for existing resources
- **Subscription Selection** - Selects appropriate subscriptions based on action type
- **Pipeline Variables** - Sets subscription IDs for later stages

#### Stage 3: Configuration Display
- **Current State Preview** - Shows current geo_region_mapping configuration
- **File Validation** - Confirms vars.tfvars file exists and is readable

#### Stage 4: Geo Management Execution
- **Script Execution** - Runs the Manage-GeoRegionMapping.ps1 script
- **Dynamic Parameters** - Uses discovered or provided subscription IDs
- **Configuration Updates** - Modifies vars.tfvars with new geo/region data
- **Change Detection** - Identifies if modifications were made

#### Stage 5: Change Commitment (Non-Dry Run)
- **Git Configuration** - Sets up pipeline identity for commits
- **Change Validation** - Verifies modifications before commit
- **Repository Update** - Commits changes back to source repository

#### Stage 6: Dry Run Preview (Dry Run Only)
- **Change Preview** - Shows what would be modified without applying
- **Git Diff Display** - Visual representation of proposed changes
- **Safety Check** - Prevents accidental modifications during testing

#### Stage 7: Terraform Validation (Non-Dry Run)
- **Terraform Installation** - Downloads and configures Terraform
- **Syntax Validation** - Validates updated vars.tfvars syntax
- **Configuration Check** - Ensures Terraform can process the file

#### Stage 8: Pipeline Summary
- **Execution Summary** - Complete overview of all stages
- **Status Reporting** - Success/failure status for each stage
- **Build Information** - Links to build details and artifacts

### Running the Pipeline

1. **Navigate to Azure DevOps Pipelines**
2. **Select "Run Pipeline"**
3. **Choose your parameters:**
   - **Action**: Select the operation to perform
   - **Geographic Region**: Choose EMEA or UAE
   - **Azure Region**: Select the specific Azure region (for region operations)
   - **Subscription IDs**: Provide required subscription IDs
   - **Dry Run**: Set to true to preview changes, false to apply them

### Pipeline Parameters

| Parameter | Description | Values |
|-----------|-------------|--------|
| `action` | Operation to perform | AddGeo, RemoveGeo, AddRegion, RemoveRegion |
| `geoName` | Geographic region | EMEA, UAE |
| `regionName` | Azure region | northeurope, westeurope, uaenorth, uaesouth |
| `useEmptySubscriptions` | Auto-discover empty subscriptions | true, false |
| `geoPlatformSubscriptionId` | Platform subscription (for AddGeo when not using auto-discovery) | GUID string |
| `regionSubscriptionId` | Region subscription (for AddRegion when not using auto-discovery) | GUID string |
| `environment` | Target environment | dev, uat, prd |
| `tenantName` | Tenant configuration | Tenant001, Tenant002 |
| `dryRun` | Preview mode | true, false |

## Enhanced Empty Subscription Discovery

The pipeline now includes advanced empty subscription discovery functionality, similar to your Bicep pipeline:

### How It Works

1. **Tenant Scanning**: Scans all enabled subscriptions in the Azure tenant
2. **Resource Detection**: Checks each subscription for:
   - Resource groups
   - Individual resources (some may exist outside resource groups)
3. **Empty Classification**: Considers a subscription "empty" if it has zero resources
4. **Automatic Selection**: Selects the first available empty subscription(s) for the operation

### Benefits

- **No Manual Subscription Management**: Eliminates need to manually track and provide subscription IDs
- **Prevents Resource Conflicts**: Ensures new deployments use truly empty subscriptions
- **Dynamic Discovery**: Adapts to changing subscription landscape automatically
- **Cost Optimization**: Uses existing empty subscriptions before creating new ones

### Usage Modes

#### Automatic Mode (Recommended)
```yaml
useEmptySubscriptions: true
geoPlatformSubscriptionId: '00000000-0000-0000-0000-000000000000'  # Placeholder
regionSubscriptionId: '00000000-0000-0000-0000-000000000000'       # Placeholder
```

#### Manual Mode
```yaml
useEmptySubscriptions: false
geoPlatformSubscriptionId: 'your-actual-subscription-id'
regionSubscriptionId: 'your-actual-subscription-id'
```

### Pipeline Integration

The empty subscription discovery is integrated as a dedicated pipeline stage:

- **Conditional Execution**: Only runs when `useEmptySubscriptions` is true
- **Action-Specific Logic**: Discovers different numbers of subscriptions based on action type
- **Variable Output**: Sets pipeline variables for later stages to consume
- **Error Handling**: Fails fast if insufficient empty subscriptions are found

## Region Configurations

The script includes predefined network configurations for each region:

### EMEA Regions

**westeurope:**
- Network Hub: `10.0.0.0/22`
- Gateway Subnet: `10.0.0.0/26`
- Azure Firewall: `10.0.0.64/26`
- Management Subnet: `10.0.0.128/26`
- DNS Inbound: `10.0.0.192/26`
- DNS Outbound: `10.0.1.0/26`

**northeurope:**
- Network Hub: `10.0.4.0/22`
- Gateway Subnet: `10.0.4.0/26`
- Azure Firewall: `10.0.4.64/26`
- Management Subnet: `10.0.4.128/26`
- DNS Inbound: `10.0.4.192/26`
- DNS Outbound: `10.0.5.0/26`

### UAE Regions

**uaenorth:**
- Network Hub: `10.0.1.0/24`
- Gateway Subnet: `10.0.1.0/26`
- Azure Firewall: `10.0.1.64/26`
- DNS Inbound: `10.0.1.128/26`
- DNS Outbound: `10.0.1.192/26`

**uaesouth:**
- Network Hub: `10.0.2.0/24`
- Gateway Subnet: `10.0.2.0/26`
- Azure Firewall: `10.0.2.64/26`
- DNS Inbound: `10.0.2.128/26`
- DNS Outbound: `10.0.2.192/26`

## Testing Locally

Use the test script to validate functionality before using in production:

```powershell
.\Test-GeoRegionMapping.ps1
```

The test script will:
- Create a backup of your vars file
- Run various test scenarios
- Show before/after configuration
- Validate parameter handling

## Safety Features

### Backup Creation
- Automatic backup creation before any changes
- Timestamped backup files
- Manual restoration if needed

### Validation
- Parameter validation based on action type
- Geo-region combination validation
- Terraform syntax validation (in pipeline)
- Duplicate detection and prevention

### Dry Run Mode
- Preview changes without applying
- Shows git diff of proposed changes
- Allows validation before committing

## Error Handling

The script includes comprehensive error handling:
- Parameter validation errors
- File access errors  
- Terraform syntax errors
- Git operation errors
- Network configuration conflicts

## Example Workflows

### Adding a New Region with Auto-Discovery

1. **Run Pipeline** with parameters:
   - Action: `AddRegion`
   - Geo: `UAE`
   - Region: `uaesouth`
   - Use Empty Subscriptions: `true`
   - Dry Run: `true` (first run)

2. **Pipeline Execution Flow**:
   - Stage 1: Validates parameters ✅
   - Stage 2: Discovers empty subscriptions → finds subscription `sub-12345`
   - Stage 3: Shows current configuration
   - Stage 4: Executes script with discovered subscription ID
   - Stage 6: Shows preview of changes (dry run mode)

3. **Review the changes** in the pipeline output

4. **Re-run Pipeline** with:
   - Same parameters
   - Dry Run: `false` (to apply)

### Adding a New Geo with Manual Subscriptions

1. **Run Pipeline** with parameters:
   - Action: `AddGeo`
   - Geo: `APAC` (if supported)
   - Use Empty Subscriptions: `false`
   - Geo Platform Subscription ID: `your-subscription-id`
   - Dry Run: `true`

2. **Pipeline Execution Flow**:
   - Stage 1: Validates parameters and subscription IDs ✅
   - Stage 2: Skipped (not using auto-discovery)
   - Stage 3: Shows current configuration
   - Stage 4: Executes script with provided subscription ID
   - Stage 6: Shows preview of changes

3. **Apply changes** by re-running with Dry Run: `false`

## Troubleshooting

### Common Issues

1. **"Could not find geo_region_mapping"**
   - Ensure the vars file has the correct format
   - Check file path and permissions

2. **"Geo X does not exist"**
   - Verify the geo name exists in the configuration
   - Use `AddGeo` to create new geos first

3. **"Invalid region for geo"**
   - Check the allowed region combinations
   - EMEA: northeurope, westeurope
   - UAE: uaenorth, uaesouth

4. **"Terraform validation failed"**
   - Check the resulting vars file syntax
   - Ensure all required Terraform variables are present

### Debug Mode

Add `-Verbose` to any script execution for detailed logging:

```powershell
.\Manage-GeoRegionMapping.ps1 -Action "AddRegion" -VarsFilePath "config/Tenant001/vars.tfvars" -GeoName "UAE" -RegionName "uaesouth" -RegionSubscriptionId "your-sub-id" -Verbose
```

## Contributing

When adding new regions or geos:

1. **Update the region configurations** in the script
2. **Add validation rules** for new combinations  
3. **Update the pipeline parameters** with new options
4. **Test thoroughly** with the test script
5. **Update this documentation**

## Security Considerations

- **Subscription IDs**: Treated as sensitive data in pipeline
- **Backup Files**: Contain configuration data - handle appropriately
- **Git Commits**: Automated commits include configuration changes
- **Access Control**: Ensure proper permissions for pipeline execution

## Support

For issues or questions:
1. Check the pipeline logs for detailed error messages
2. Run the test script locally for debugging
3. Review the generated backup files for configuration state
4. Validate Terraform syntax independently if needed
