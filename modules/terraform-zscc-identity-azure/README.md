# Zscaler Cloud Connector / Azure Managed Identity Module

This module manages the User Assigned Managed Identity/Identities used by Cloud Connector VM(s)/VMSS and (optionally) the VMSS Function App. By default it preserves its original behavior: `existing_cc_vm_managed_identity` and `existing_function_app_managed_identity` both default to `true`, so the module does a `data` source lookup of a Managed Identity that already exists (name/resource group supplied via `cc_vm_managed_identity_name`/`cc_vm_managed_identity_rg` and `function_app_managed_identity_name`/`function_app_managed_identity_rg`) and republishes its `id`/`client_id`/`principal_id` as outputs.

Set `existing_cc_vm_managed_identity` and/or `existing_function_app_managed_identity` to `false` to have this module create a new Managed Identity with that same name/resource group instead of looking one up (requires `location`, and accepts `global_tags`). Module outputs are identical regardless of which mode is used, so no downstream module needs to change.

Optionally, set `network_role_assignment_enabled = true` to have the module assign a role (default: the built-in `Network Contributor` role; override via `network_role_assignment_role_name` for a minimally-scoped custom role, minimum requirement `Microsoft.Network/networkInterfaces/read`) to the CC VM Managed Identity at `network_role_assignment_scope` (a Subscription or Resource Group resource ID supplied by the caller, e.g. from a sibling network module's output). This is off by default since the identity may already carry this role assignment outside of Terraform. There is no equivalent automated role assignment for the Function App Managed Identity — it needs an "increased permission set" per the VMSS example docs, but no specific role name is documented, so it is left to the caller/BYO identity's existing permissions.


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
| [azurerm_role_assignment.cc_vm_network_role](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_user_assigned_identity.cc_vm](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) | resource |
| [azurerm_user_assigned_identity.function_app](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) | resource |
| [azurerm_user_assigned_identity.function_app_identity_selected](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/user_assigned_identity) | data source |
| [azurerm_user_assigned_identity.selected](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/user_assigned_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_cc_vm_managed_identity_name"></a> [cc\_vm\_managed\_identity\_name](#input\_cc\_vm\_managed\_identity\_name) | Azure Managed Identity name to attach to the CC VM. E.g zspreview-66117-mi | `string` | n/a | yes |
| <a name="input_cc_vm_managed_identity_rg"></a> [cc\_vm\_managed\_identity\_rg](#input\_cc\_vm\_managed\_identity\_rg) | Resource Group of the Azure Managed Identity name to attach to the CC VM. E.g. edgeconnector\_rg\_1 | `string` | n/a | yes |
| <a name="input_existing_cc_vm_managed_identity"></a> [existing\_cc\_vm\_managed\_identity](#input\_existing\_cc\_vm\_managed\_identity) | Set to true (default) to do a data lookup of an existing Managed Identity named by cc\_vm\_managed\_identity\_name/cc\_vm\_managed\_identity\_rg. Set to false to have this module create a new Managed Identity with that name/resource group instead. | `bool` | `true` | no |
| <a name="input_existing_function_app_managed_identity"></a> [existing\_function\_app\_managed\_identity](#input\_existing\_function\_app\_managed\_identity) | Set to true (default) to do a data lookup of an existing Managed Identity named by function\_app\_managed\_identity\_name/function\_app\_managed\_identity\_rg. Set to false to have this module create a new Managed Identity with that name/resource group instead. Only relevant when vmss\_enabled is true. | `bool` | `true` | no |
| <a name="input_function_app_managed_identity_name"></a> [function\_app\_managed\_identity\_name](#input\_function\_app\_managed\_identity\_name) | Azure Managed Identity name to attach to the Function App. E.g zspreview-66117-mi | `string` | `""` | no |
| <a name="input_function_app_managed_identity_rg"></a> [function\_app\_managed\_identity\_rg](#input\_function\_app\_managed\_identity\_rg) | Resource Group of the Azure Managed Identity name to attach to the Function App. E.g. edgeconnector\_rg\_1 | `string` | `""` | no |
| <a name="input_global_tags"></a> [global\_tags](#input\_global\_tags) | Map of tags applied to any Managed Identity created by this module. Not applied when referencing an existing Managed Identity via data source. | `map(string)` | `{}` | no |
| <a name="input_location"></a> [location](#input\_location) | Azure region to create the Managed Identity/Identities in. Only required when existing\_cc\_vm\_managed\_identity and/or existing\_function\_app\_managed\_identity are set to false. | `string` | `null` | no |
| <a name="input_network_role_assignment_enabled"></a> [network\_role\_assignment\_enabled](#input\_network\_role\_assignment\_enabled) | Set to true to have this module assign network\_role\_assignment\_role\_name to the CC VM Managed Identity at network\_role\_assignment\_scope. Default is false, since the identity may already carry this role assignment outside of Terraform. | `bool` | `false` | no |
| <a name="input_network_role_assignment_role_name"></a> [network\_role\_assignment\_role\_name](#input\_network\_role\_assignment\_role\_name) | Role name to assign to the CC VM Managed Identity when network\_role\_assignment\_enabled is true. Defaults to the built-in Network Contributor role; override with a custom role name if using a minimally-scoped custom role (minimum requirement: Microsoft.Network/networkInterfaces/read). | `string` | `"Network Contributor"` | no |
| <a name="input_network_role_assignment_scope"></a> [network\_role\_assignment\_scope](#input\_network\_role\_assignment\_scope) | Resource ID (Subscription or Resource Group) to scope the network\_role\_assignment\_role\_name role assignment to. Required when network\_role\_assignment\_enabled is true. E.g. a sibling network module's resource\_group\_id output. | `string` | `null` | no |
| <a name="input_vmss_enabled"></a> [vmss\_enabled](#input\_vmss\_enabled) | Default is false non non-vmss deployments. If true, module will do a data lookup (or create, per existing\_function\_app\_managed\_identity) for an additional managed identity resource for Function App in the same subscription | `bool` | `false` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_function_app_managed_identity_client_id"></a> [function\_app\_managed\_identity\_client\_id](#output\_function\_app\_managed\_identity\_client\_id) | The Client ID of the User Assigned Identity dedicated for VMSS Function App |
| <a name="output_function_app_managed_identity_id"></a> [function\_app\_managed\_identity\_id](#output\_function\_app\_managed\_identity\_id) | User Managed Identity ID dedicated for VMSS Function App |
| <a name="output_function_app_managed_identity_principal_id"></a> [function\_app\_managed\_identity\_principal\_id](#output\_function\_app\_managed\_identity\_principal\_id) | The Object(Principal) ID of the User Assigned Identity dedicated for VMSS Function App |
| <a name="output_managed_identity_client_id"></a> [managed\_identity\_client\_id](#output\_managed\_identity\_client\_id) | The Client ID of the User Assigned Identity |
| <a name="output_managed_identity_id"></a> [managed\_identity\_id](#output\_managed\_identity\_id) | User Managed Identity ID |
| <a name="output_managed_identity_principal_id"></a> [managed\_identity\_principal\_id](#output\_managed\_identity\_principal\_id) | The Object(Principal) ID of the User Assigned Identity |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->