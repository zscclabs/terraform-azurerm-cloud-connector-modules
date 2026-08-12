# Zscaler Cloud Connector / Azure Key Vault Module

This module manages the Azure Key Vault used to store Zscaler Cloud Connector provisioning credentials (referenced by the root README.md's "Azure Requirements" prerequisites). By default (`existing_key_vault = false`, `secrets_enabled = true`) it creates a new Key Vault with **RBAC authorization enabled** (no legacy access-policy support) and populates it with three secrets that the Cloud Connector provisioning agent expects to find by name:

| Secret name | Source variable | Contents |
|---|---|---|
| `api-key` | `zscaler_api_key` | Value from the API Key Management page on the Zscaler Admin Console |
| `username` | `zscaler_username` | Zscaler Cloud Connector provisioning username |
| `password` | `zscaler_password` | Zscaler Cloud Connector provisioning password |

Set `existing_key_vault = true` (with `existing_key_vault_name`/`existing_key_vault_rg`) to instead reference an existing/BYO Key Vault. In that mode this module never creates or manages secrets — the vault is assumed to already be populated, matching the manual prerequisite flow this module is meant to make optional.

Pass the Cloud Connector Managed Identity's `principal_id` (e.g. the `managed_identity_principal_id` output of `terraform-zscc-identity-azure`) as `secrets_reader_principal_id` to have this module grant it the built-in `Key Vault Secrets User` role on the vault. This is decoupled by design — this module does not reference the identity module directly, so wiring happens at the caller level.

**Deployer permissions caveat:** because the created Key Vault uses RBAC authorization, the principal running `terraform apply` needs its own `Key Vault Secrets Officer` (or broader, e.g. `Key Vault Administrator`/`Owner`) RBAC role on the vault before this module's `azurerm_key_vault_secret` resources can be written — RBAC grants no implicit access to the creator. If the deployer doesn't already hold sufficient permissions, set `assign_deployer_secrets_officer_role = true` and `terraform_deployer_object_id` to have this module self-grant `Key Vault Secrets Officer` to the deployer before writing secrets. This is off by default. Note this self-grant is itself an RBAC role assignment, so it requires the deployer to already hold `Microsoft.Authorization/roleAssignments/write` (e.g. via `Owner`/`User Access Administrator`) - a `Contributor`-only principal cannot use it. In that case, set `secrets_enabled = false` instead: the vault (and anything else this module manages, e.g. its Private Endpoint) still gets created, and the three secrets can be populated afterward by whoever has the necessary access.

Key Vault names must be globally unique across Azure, 3-24 characters, alphanumeric/hyphen only. If `key_vault_name` is left unset, a name is derived from `name_prefix`/`resource_tag` and truncated to 24 characters - be aware this truncation could collide with another deployment if `resource_tag` isn't unique; pass `key_vault_name` explicitly to avoid this.

## Private Endpoint / network lockdown

By default the Key Vault created by this module is reachable over the public internet, matching prior behavior. Set `private_endpoint_enabled = true` with `private_endpoint_subnet_id` (e.g. `module.network.private_endpoint_subnet_id`) and `vnet_id` (e.g. `module.network.virtual_network_id`) to create a Private Endpoint for it - this works whether the vault is created by this module or referenced via `existing_key_vault`. A `privatelink.vaultcore.azure.net` Private DNS Zone is created and linked to `vnet_id` automatically unless `existing_private_dns_zone_id` supplies one to reuse (e.g. a hub-shared zone).

This does not by itself restrict public network access - `private_endpoint_enabled` and `public_network_access_enabled`/`network_acls_default_action` are independent toggles by design. For a fully private posture, also set `public_network_access_enabled = false` and `network_acls_default_action = "Deny"`.

Cloud Connector VM/VMSS instances need no code changes to reach a privately-endpointed Key Vault - as long as they sit in the same VNet passed as `vnet_id`, they resolve the Private Endpoint IP automatically via Azure's default DNS.

**Caveat when `public_network_access_enabled = false`:** this module's `azurerm_key_vault_secret` resources (`api-key`/`username`/`password`) are Terraform data-plane calls, subject to the same network lockdown as everything else on the vault. If Terraform is run from outside the VNet (e.g. a local workstation, most CI runners) with `public_network_access_enabled = false`, writing these secrets - and any `terraform plan`/`apply` afterward, since Terraform refreshes all resources in state by default - will fail with `403 Forbidden`/`ForbiddenByConnection`. This is independent of, and takes priority over, `network_acls_ip_rules`/`network_acls_default_action`: with `public_network_access_enabled = false`, only Private Link traffic or specifically-trusted Azure services can connect at all, regardless of any IP allowlist. Either run Terraform from inside the VNet (e.g. via the bastion host), or temporarily set `public_network_access_enabled = true` (scoped down with `network_acls_ip_rules`/`network_acls_default_action = "Deny"` if desired) for the apply that writes the secrets, then flip it back to `false` afterward. Flipping back requires `terraform plan -refresh=false`/`apply -refresh=false` for that one cycle, since a normal refresh against the still-locked-down real vault will itself 403 before Terraform can compute the diff that re-opens it.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 0.13.7, < 2.0.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 3.108.0, <= 3.116 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | >= 3.108.0, <= 3.116 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_key_vault.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault) | resource |
| [azurerm_key_vault_secret.api_key](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) | resource |
| [azurerm_key_vault_secret.password](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) | resource |
| [azurerm_key_vault_secret.username](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault_secret) | resource |
| [azurerm_private_dns_zone.key_vault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone) | resource |
| [azurerm_private_dns_zone_virtual_network_link.key_vault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone_virtual_network_link) | resource |
| [azurerm_private_endpoint.key_vault](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint) | resource |
| [azurerm_role_assignment.cc_secrets_reader](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.deployer_secrets_officer](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |
| [azurerm_key_vault.existing](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/key_vault) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_assign_deployer_secrets_officer_role"></a> [assign\_deployer\_secrets\_officer\_role](#input\_assign\_deployer\_secrets\_officer\_role) | Set to true to have this module grant the built-in 'Key Vault Secrets Officer' role to terraform\_deployer\_object\_id, so the Terraform-executing principal can write the zscaler\_api\_key/zscaler\_username/zscaler\_password secrets without already holding that permission on the Key Vault. Default is false. Only useful when secrets\_enabled is true (or you plan to manage secrets manually afterward) - and itself requires the deployer to already hold Microsoft.Authorization/roleAssignments/write, which not every principal has. | `bool` | `false` | no |
| <a name="input_existing_key_vault"></a> [existing\_key\_vault](#input\_existing\_key\_vault) | Set to true if you wish to use an existing Key Vault instead of creating a new one. Default is false, meaning this module will create a new Key Vault. | `bool` | `false` | no |
| <a name="input_existing_key_vault_name"></a> [existing\_key\_vault\_name](#input\_existing\_key\_vault\_name) | Name of existing Key Vault. Required when existing\_key\_vault is true. | `string` | `""` | no |
| <a name="input_existing_key_vault_rg"></a> [existing\_key\_vault\_rg](#input\_existing\_key\_vault\_rg) | Resource Group of existing Key Vault. Required when existing\_key\_vault is true. | `string` | `""` | no |
| <a name="input_existing_private_dns_zone_id"></a> [existing\_private\_dns\_zone\_id](#input\_existing\_private\_dns\_zone\_id) | ID of an existing privatelink.vaultcore.azure.net Private DNS Zone to reuse (e.g. a hub-shared zone) instead of creating/linking a new one. Only used when private\_endpoint\_enabled is true. | `string` | `null` | no |
| <a name="input_global_tags"></a> [global\_tags](#input\_global\_tags) | Populate any custom user defined tags from a map | `map(string)` | `{}` | no |
| <a name="input_key_vault_name"></a> [key\_vault\_name](#input\_key\_vault\_name) | Explicit name for the Key Vault created by this module. If left null, a name is derived from name\_prefix and resource\_tag and truncated to Azure's 24 character Key Vault name limit. Only used when existing\_key\_vault is false. | `string` | `null` | no |
| <a name="input_location"></a> [location](#input\_location) | Cloud Connector Azure Region | `string` | n/a | yes |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | A prefix to associate to all the keyvault module resources | `string` | `null` | no |
| <a name="input_network_acls_default_action"></a> [network\_acls\_default\_action](#input\_network\_acls\_default\_action) | Default action (Allow or Deny) for the Key Vault network ACLs created by this module. Only used when existing\_key\_vault is false. | `string` | `"Allow"` | no |
| <a name="input_network_acls_ip_rules"></a> [network\_acls\_ip\_rules](#input\_network\_acls\_ip\_rules) | List of IP or CIDR ranges to allow through the Key Vault network ACLs created by this module. Only used when existing\_key\_vault is false. | `list(string)` | `[]` | no |
| <a name="input_network_acls_subnet_ids"></a> [network\_acls\_subnet\_ids](#input\_network\_acls\_subnet\_ids) | List of subnet IDs (with the Microsoft.KeyVault service endpoint enabled) to allow through the Key Vault network ACLs created by this module. Only used when existing\_key\_vault is false. | `list(string)` | `[]` | no |
| <a name="input_private_endpoint_enabled"></a> [private\_endpoint\_enabled](#input\_private\_endpoint\_enabled) | Create a Private Endpoint for the Key Vault if set to true. This does not by itself restrict public network access - also set public\_network\_access\_enabled to false and network\_acls\_default\_action to "Deny" for a fully private posture. | `bool` | `false` | no |
| <a name="input_private_endpoint_subnet_id"></a> [private\_endpoint\_subnet\_id](#input\_private\_endpoint\_subnet\_id) | Subnet ID to deploy the Key Vault Private Endpoint into, e.g. module.network.private\_endpoint\_subnet\_id. Required when private\_endpoint\_enabled is true. | `string` | `null` | no |
| <a name="input_public_network_access_enabled"></a> [public\_network\_access\_enabled](#input\_public\_network\_access\_enabled) | Whether public network access is allowed on the Key Vault created by this module. Only used when existing\_key\_vault is false. | `bool` | `true` | no |
| <a name="input_purge_protection_enabled"></a> [purge\_protection\_enabled](#input\_purge\_protection\_enabled) | Whether purge protection is enabled on the Key Vault created by this module. Default is false to allow examples/testing to be freely destroyed and recreated (e.g. via the zsec wrapper script); set to true for production deployments. Only used when existing\_key\_vault is false. | `bool` | `false` | no |
| <a name="input_resource_group"></a> [resource\_group](#input\_resource\_group) | Main Resource Group Name | `string` | n/a | yes |
| <a name="input_resource_tag"></a> [resource\_tag](#input\_resource\_tag) | A tag to associate to all the keyvault module resources | `string` | `null` | no |
| <a name="input_secrets_enabled"></a> [secrets\_enabled](#input\_secrets\_enabled) | Whether this module writes the zscaler\_api\_key/zscaler\_username/zscaler\_password secrets into the Key Vault it creates. Default is true. Set to false to create the vault (and optionally its Private Endpoint/role assignments) without writing secret values - e.g. when the deployer lacks Key Vault RBAC permissions to write secrets and they will be populated later by someone who does. Only used when existing\_key\_vault is false; BYO Key Vaults never have secrets written by this module regardless of this setting. | `bool` | `true` | no |
| <a name="input_secrets_reader_principal_id"></a> [secrets\_reader\_principal\_id](#input\_secrets\_reader\_principal\_id) | Principal (Object) ID of the Cloud Connector Managed Identity to grant the built-in 'Key Vault Secrets User' RBAC role on this Key Vault. Leave null (default) to skip the role assignment, e.g. if access is already granted outside of Terraform. | `string` | `null` | no |
| <a name="input_sku_name"></a> [sku\_name](#input\_sku\_name) | SKU for the Key Vault created by this module. Only used when existing\_key\_vault is false. | `string` | `"standard"` | no |
| <a name="input_soft_delete_retention_days"></a> [soft\_delete\_retention\_days](#input\_soft\_delete\_retention\_days) | Number of days that items should be retained for once soft-deleted on the Key Vault created by this module. Only used when existing\_key\_vault is false. | `number` | `90` | no |
| <a name="input_terraform_deployer_object_id"></a> [terraform\_deployer\_object\_id](#input\_terraform\_deployer\_object\_id) | Object ID of the principal running Terraform (user, service principal, or managed identity). Required when assign\_deployer\_secrets\_officer\_role is true. | `string` | `null` | no |
| <a name="input_vnet_id"></a> [vnet\_id](#input\_vnet\_id) | VNet ID to link the privatelink.vaultcore.azure.net Private DNS Zone to, e.g. module.network.virtual\_network\_id. Required when private\_endpoint\_enabled is true and existing\_private\_dns\_zone\_id is not set. | `string` | `null` | no |
| <a name="input_zscaler_api_key"></a> [zscaler\_api\_key](#input\_zscaler\_api\_key) | Zscaler Cloud Connector API Key (from the API Key Management page on the Zscaler Admin Console), stored as the 'api-key' secret. Required when existing\_key\_vault is false and secrets\_enabled is true; left null otherwise. | `string` | `null` | no |
| <a name="input_zscaler_password"></a> [zscaler\_password](#input\_zscaler\_password) | Zscaler Cloud Connector provisioning password, stored as the 'password' secret. Required when existing\_key\_vault is false and secrets\_enabled is true; left null otherwise. | `string` | `null` | no |
| <a name="input_zscaler_username"></a> [zscaler\_username](#input\_zscaler\_username) | Zscaler Cloud Connector provisioning username, stored as the 'username' secret. Required when existing\_key\_vault is false and secrets\_enabled is true; left null otherwise. | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_key_vault_id"></a> [key\_vault\_id](#output\_key\_vault\_id) | ID of the Key Vault (created by this module, or the existing/BYO Key Vault referenced by existing\_key\_vault\_name/existing\_key\_vault\_rg) |
| <a name="output_key_vault_name"></a> [key\_vault\_name](#output\_key\_vault\_name) | Name of the Key Vault |
| <a name="output_key_vault_uri"></a> [key\_vault\_uri](#output\_key\_vault\_uri) | URI of the Key Vault. Feed this into the azure\_vault\_url variable consumed by the Cloud Connector VM/VMSS userdata and Function App |
| <a name="output_private_endpoint_id"></a> [private\_endpoint\_id](#output\_private\_endpoint\_id) | ID of the Key Vault Private Endpoint (empty string if private\_endpoint\_enabled is false) |
| <a name="output_private_endpoint_ip_address"></a> [private\_endpoint\_ip\_address](#output\_private\_endpoint\_ip\_address) | Private IP address assigned to the Key Vault Private Endpoint (empty string if private\_endpoint\_enabled is false) |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->