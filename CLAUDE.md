# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains Terraform modules for deploying Zscaler Cloud Connector (CC) resources in Microsoft Azure. Cloud Connector provides secure connectivity between Azure workloads and Zscaler's security cloud. The repository supports both greenfield (new/POV) and brownfield (existing/production) deployments.

## Repository Structure

### Modules (`modules/`)
Reusable Terraform modules that are composed together in example deployments:
- **terraform-zscc-network-azure**: VNet, subnets, NAT Gateway, route tables
- **terraform-zscc-ccvm-azure**: Cloud Connector VMs with network interfaces (standalone, not for VMSS)
- **terraform-zscc-ccvmss-azure**: Cloud Connector Virtual Machine Scale Sets for auto-scaling
- **terraform-zscc-lb-azure**: Azure Standard Load Balancer configuration
- **terraform-zscc-nsg-azure**: Network Security Groups and rules for CC mgmt/service interfaces
- **terraform-zscc-bastion-azure**: Bastion jump host for SSH access (greenfield only)
- **terraform-zscc-workload-azure**: Test workload VMs (greenfield only)
- **terraform-zscc-identity-azure**: References User Managed Identity for CC VMs
- **terraform-zscc-function-app-azure**: Azure Function App for VMSS lifecycle management (includes zip file)
- **terraform-zscc-private-dns-azure**: Private DNS Resolver for ZPA integration
- **terraform-zscc-ztags-azure**: Zscaler Tags integration via Event Grid

### Examples (`examples/`)
Complete deployment templates organized by use case:

**Greenfield deployments** (includes bastion, test workloads, new network infrastructure):
- `base` or `base_1cc`: Single CC deployment
- `base_1cc_zpa`: Single CC with ZPA (Private DNS Resolver)
- `base_cc_lb`: Multiple CCs with Azure Load Balancer
- `base_cc_lb_zpa`: Load balanced CCs with ZPA
- `base_cc_vmss`: Cloud Connectors in VMSS with auto-scaling
- `base_cc_vmss_zpa`: VMSS deployment with ZPA

**Brownfield deployments** (production, bring-your-own network):
- `cc_lb`: Custom deployment with Load Balancer
- `cc_vmss`: Custom deployment with VMSS

**Standalone**:
- `ztags_standalone`: Zscaler Tags enablement only (no CC resources)

### Scripts
- `examples/zsec`: Interactive bash wrapper for deployment selection and Terraform operations
- `scripts/manual_sync.sh`: Manually sync VMSS function app triggers

## Architecture Patterns

### Module Composition Flow
Examples compose modules in this typical order:
1. **Network module** creates Resource Group, VNet, subnets (CC, workload, public)
2. **Bastion module** (greenfield only) creates jump host in public subnet
3. **Workload module** (greenfield only) creates test VMs
4. **Identity module** references existing Azure Managed Identity
5. **NSG module** creates security rules for CC interfaces
6. **CC VM/VMSS module** deploys Cloud Connector instances with user_data bootstrap
7. **Load Balancer module** (if enabled) distributes traffic across CCs
8. **Function App module** (VMSS only) handles scaling events
9. **Private DNS module** (ZPA deployments) enables ZPA integration

### Cloud Connector Bootstrap
CCs require user_data with these parameters for registration:
- `CC_URL`: Zscaler provisioning URL
- `AZURE_VAULT_URL`: Azure Key Vault with CC credentials (api key, username, password)
- `HTTP_PROBE_PORT`: Health probe port
- `AZURE_MANAGED_IDENTITY_CLIENT_ID`: Managed Identity for Key Vault access

### Network Interface Ordering (Critical)
**DO NOT modify NIC ordering** on Cloud Connector VMs:
1. First interface MUST be "Management" (no IP forwarding)
2. Subsequent interfaces are "Service" interfaces (IP forwarding enabled)

CC explicitly expects this ordering and associates management services with the first interface.

### Availability and Scaling
- **Availability Sets**: Manual scaling deployments use availability sets for fault tolerance
- **Availability Zones**: Set `zones_enabled=true` and specify `zones` to distribute CCs across AZs
- **VMSS**: Auto-scaling with Azure Function App for lifecycle management
- **Load Balancer**: Azure Standard Load Balancer recommended for multi-CC deployments

### China Region Handling
Marketplace image publisher/offer differs in Azure China:
- Public/Gov: `zscaler1579058425289` / `zia_cloud_connector`
- China: `cbcnetworks` / `zscaler-cloud-connector`

The code automatically detects China regions and switches publishers.

## Common Development Commands

### Terraform Operations
```bash
# Format code
terraform fmt -recursive

# Validate modules
cd modules/terraform-zscc-<module-name>
terraform init
terraform validate

# Deploy via zsec wrapper (interactive)
cd examples
./zsec up

# Deploy manually
cd examples/<deployment-type>
terraform init
terraform plan
terraform apply

# Destroy deployment
./zsec destroy  # or terraform destroy
```

### Pre-commit Hooks
```bash
# Install and run pre-commit (requires pre-commit tool installed)
pre-commit run --all-files
```

The `.pre-commit-config.yaml` enforces:
- `terraform_fmt`: Format checking
- `terraform_validate`: Validation
- `terraform_docs`: Auto-generate module documentation
- `terraform_tflint`: Linting for best practices
- `gitlint`: Commit message linting
- `detect-secrets`: Prevent secret commits

### CI/CD
GitHub Actions workflow (`.github/workflows/ci.yml`) runs on push/PR:
- `terraform fmt -check -recursive`
- Init and validate each module individually

### VMSS Manual Sync
After VMSS deployment or changes:
```bash
cd scripts
./manual_sync.sh <subscription_id> <resource_group> <function_app_name>
```

## Function App Private Storage Architecture (VMSS Deployments)

VMSS deployments now use **fully private storage accounts** with private endpoints for enhanced security:

### Network Architecture
The function app requires two dedicated subnets (auto-created by network module when `function_app_enabled = true`):

1. **VNet Integration Subnet** (`function-app-vnet-integration-subnet`):
   - Delegated to `Microsoft.Web/serverFarms`
   - Allows function app to access VNet resources privately
   - Default CIDR: `/28` subnet (auto-calculated)

2. **Storage Private Endpoints Subnet** (`function-app-storage-pe-subnet`):
   - Hosts 5 private endpoints for storage services
   - Default CIDR: `/28` subnet (auto-calculated)

### Private Endpoints Created
For each storage account, 5 private endpoints are created:
- **Blob**: Function app package deployment (`WEBSITE_RUN_FROM_PACKAGE`)
- **File**: Function app backend storage (Azure Files)
- **Table**: Runtime state/metadata
- **Queue**: Queue triggers (if used)
- **Web**: Static website storage (if used)

### Private DNS Zones
Network module automatically creates and links Private DNS zones to VNet:
- `privatelink.blob.core.windows.net`
- `privatelink.file.core.windows.net`
- `privatelink.table.core.windows.net`
- `privatelink.queue.core.windows.net`
- `privatelink.web.core.windows.net`

These zones ensure storage account FQDNs resolve to private endpoint IPs within the VNet.

### Function App Configuration
- `storage_use_private_endpoint = true`: Disables public access to storage
- `public_network_access_enabled = false`: Fully private function app
- `storage_uses_managed_identity = true`: Uses managed identity instead of access keys
- `vnet_route_all_enabled = true`: Routes all outbound traffic through VNet

### Managed Identity Permissions
The function app's managed identity must have:
- **Storage Blob Data Owner** role on storage account (for package deployment)
- **Storage Account Contributor** or similar for file/table/queue access

## Azure Prerequisites

Before deployment, ensure:

1. **Azure Service Principal** with credentials:
   - Application (client) ID
   - Directory (tenant) ID
   - Client Secret Value

2. **Azure Managed Identity** with Network Contributor role (or custom role with `Microsoft.Network/networkInterfaces/read`)

3. **Azure Key Vault** with:
   - Zscaler CC credentials stored (api key, username, password)
   - Access policy granting Managed Identity: Get, List secrets

4. **Marketplace Terms Accepted**:
   ```bash
   az vm image terms accept --urn zscaler1579058425289:zia_cloud_connector:zs_ser_gen1_cc_01:latest
   ```

5. **Host Encryption** (if needed): Subscribe to feature per [Microsoft docs](https://learn.microsoft.com/en-us/azure/virtual-machines/disks-enable-host-based-encryption-portal?tabs=azure-cli#prerequisites)

## Terraform Version Requirements

- Terraform: >= 0.13.7, < 2.0.0 (v1.1.9+ recommended for Apple M1 support)
- Providers:
  - azurerm: >= 3.108.0, <= 3.116
  - random: ~> 3.3.x
  - local: ~> 2.2.x (modules use ~> 2.5.0)
  - null: ~> 3.1.x
  - tls: ~> 3.4.x
  - azapi: ~> 2.2.x

## Variable Patterns

Examples use `terraform.tfvars` for configuration. Common variables:
- `name_prefix`: Resource naming prefix
- `arm_location`: Azure region
- `cc_count`: Number of Cloud Connectors (manual scaling)
- `zones_enabled`/`zones`: Availability zone distribution
- `cc_vm_prov_url`: Zscaler provisioning URL (from CC portal)
- `azure_vault_url`: Key Vault URL with CC credentials
- `cc_vm_managed_identity_name`/`cc_vm_managed_identity_rg`: Managed Identity reference
- `zpa_enabled`: Enable Private DNS for ZPA integration (brownfield)
- `reuse_nsg`: Share single NSG across all CCs vs. one per CC

## Module Documentation

Module READMEs are auto-generated by `terraform-docs` pre-commit hook. The `<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->` marker indicates where auto-generated content begins. Do not manually edit below this marker.
