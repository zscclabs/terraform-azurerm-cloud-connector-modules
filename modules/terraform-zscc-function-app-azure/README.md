# Zscaler Cloud Connector / Azure Function App Module

This module provides the necessary resource creation and configuration parameters to deploy the Zscaler generated Azure Function App and dependencies required for management and health monitoring of Cloud Connectors deployed in a Virtual Machine Scale Set (VMSS). Recommended configuration includes the creation of a new Azure Storage Account for Function App zip file upload/storage and runtime. For full functionality, a dedicate App Service Plan and Application Insights resource are required for custom metric ingestion and processing.

| Function ZIP Version | SHA256 Hash | GitHub Release Date/Tag |
| ----------- | --------| ------------ |
| 1.0.3 | 8cbe698b57164c757f80e93961867408bb9d172185a246833b9b78e86f671361 | 06/12/2026 - [v0.8.1](https://github.com/zscaler/terraform-azurerm-cloud-connector-modules/releases/tag/v0.8.1) |
| 1.0.2 | 8439872aac693b1d472ea0565b76585e2ac617e4323f3b6bc15dda7f15600171 | 07/11/2025 - [v0.8.0](https://github.com/zscaler/terraform-azurerm-cloud-connector-modules/releases/tag/v0.8.0) |
| 1.0.1 | aed981cf32c7cf62623f3195b8e1315afb570b43d451a0ba0e782e4ba0d828dd | 12/06/2024 - [v0.6.2](https://github.com/zscaler/terraform-azurerm-cloud-connector-modules/releases/tag/v0.6.2) |
| 1.0.0 | 8de1144256df20f970f9c382c001bad14d2de1407a9d8b7a6edd3a6c5143d3bc | 09/05/2024 - [v0.6.0](https://github.com/zscaler/terraform-azurerm-cloud-connector-modules/releases/tag/v0.6.0) |

## Storage Account / Function App network lockdown

By default the Storage Account created by this module (`existing_storage_account = false`) and the Function App are both reachable over the public internet, matching prior behavior. To lock them down:

- Set `storage_public_network_access_enabled = false` and `storage_network_rules_default_action = "Deny"` to disable public access to the Storage Account. This is independent of `storage_private_endpoint_enabled` - enabling the Private Endpoint does not by itself flip these.
- Set `storage_private_endpoint_enabled = true` with `storage_private_endpoint_subnet_id` (e.g. `module.network.private_endpoint_subnet_id`) and `vnet_id` (e.g. `module.network.virtual_network_id`) to create Private Endpoints for the Storage Account. Azure only permits a single subresource per Storage Account Private Endpoint, so one `azurerm_private_endpoint` is created per entry in `storage_private_endpoint_subresource_names` (default `blob`, `file`, `queue`, `table` - `AzureWebJobsStorage` needs blob/queue/table, and the Function App content share on a Premium/EP1 plan additionally needs file).
- Set `vnet_integration_enabled = true` with `vnet_integration_subnet_id` (e.g. `module.network.function_app_subnet_id`, a subnet delegated to `Microsoft.Web/serverFarms`) to give the Function App regional VNet Integration, so its own outbound calls to the Storage Account/Key Vault traverse the VNet instead of the public internet. **This requires `asp_sku_name = "EP1"`** - `Y1`/`FC1`/`B1` do not support regional VNet Integration and will fail at apply/runtime if combined with `vnet_integration_enabled = true`.

Cloud Connector VM/VMSS instances need no code changes to reach a privately-endpointed Storage Account/Key Vault - as long as they sit in the same VNet passed as `vnet_id`, they resolve the Private Endpoint IPs automatically via Azure's default DNS.

**Caveat when `storage_public_network_access_enabled = false`:** this module writes/reads several Storage Account data-plane objects directly - the `function-zip-container`/`zscaler_cc_function_app.zip` blob (when `upload_function_app_zip = true`) and the `azurerm_storage_share` content share (when `vnet_integration_enabled = true`). Terraform performs these as data-plane calls, subject to the same network lockdown as everything else on the account. If Terraform is run from outside the VNet (e.g. a local workstation, most CI runners) with `storage_public_network_access_enabled = false`, these resources - and any `terraform plan`/`apply` afterward, since Terraform refreshes all resources in state by default - will fail with `403 AuthorizationFailure`/`ForbiddenByConnection`. Either run Terraform from inside the VNet (e.g. via the bastion host), or temporarily set `storage_public_network_access_enabled = true` (with `storage_network_rules_ip_rules` scoped to the deployer's IP) for the apply that creates/updates these objects, then flip it back to `false` afterward. Flipping back requires `terraform plan -refresh=false`/`apply -refresh=false` for that one cycle, since a normal refresh against the still-locked-down real resource will itself 403 before Terraform can compute the diff that re-opens it.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 0.13.7, < 2.0.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 3.108.0, <= 3.116 |
| <a name="requirement_local"></a> [local](#requirement\_local) | ~> 2.5.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | >= 3.108.0, <= 3.116 |
| <a name="provider_local"></a> [local](#provider\_local) | ~> 2.5.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_application_insights.vmss_orchestration_app_insights](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_insights) | resource |
| [azurerm_linux_function_app.vmss_orchestration_app](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_function_app) | resource |
| [azurerm_linux_function_app.vmss_orchestration_app_with_manual_sync](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_function_app) | resource |
| [azurerm_log_analytics_workspace.vmss_orchestration_log_analytics_workspace](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/log_analytics_workspace) | resource |
| [azurerm_private_dns_zone.storage](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone) | resource |
| [azurerm_private_dns_zone_virtual_network_link.storage](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone_virtual_network_link) | resource |
| [azurerm_private_endpoint.storage](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint) | resource |
| [azurerm_service_plan.vmss_orchestration_app_service_plan](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/service_plan) | resource |
| [azurerm_storage_account.cc_function_storage_account](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) | resource |
| [azurerm_storage_blob.cc_function_storage_blob](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_blob) | resource |
| [azurerm_storage_container.cc_function_storage_container](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_container) | resource |
| [azurerm_storage_account.existing_storage_account](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/storage_account) | data source |
| [azurerm_subscription.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subscription) | data source |
| [local_file.manual_sync_exist_status](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_asp_sku_name"></a> [asp\_sku\_name](#input\_asp\_sku\_name) | SKU Name for the App Service Plan. Recommended Y1 (flex consumption) for function app unless not supported by Azure region. Note: regional VNet Integration (vnet\_integration\_enabled) is only supported on EP1 among these options - Y1/FC1/B1 do not support it. | `string` | `"Y1"` | no |
| <a name="input_azure_vault_url"></a> [azure\_vault\_url](#input\_azure\_vault\_url) | Azure Vault URL | `string` | n/a | yes |
| <a name="input_cc_vm_prov_url"></a> [cc\_vm\_prov\_url](#input\_cc\_vm\_prov\_url) | Zscaler Cloud Connector Provisioning URL | `string` | n/a | yes |
| <a name="input_existing_log_analytics_workspace"></a> [existing\_log\_analytics\_workspace](#input\_existing\_log\_analytics\_workspace) | Set to True if you wish to use an existing Log Analytics Workspace to associate with the AppInsights Instance. Default is false meaning Terraform module will create a new one | `bool` | `false` | no |
| <a name="input_existing_log_analytics_workspace_id"></a> [existing\_log\_analytics\_workspace\_id](#input\_existing\_log\_analytics\_workspace\_id) | ID of existing Log Analytics Workspace to associate with the AppInsights Instance. | `string` | `""` | no |
| <a name="input_existing_storage_account"></a> [existing\_storage\_account](#input\_existing\_storage\_account) | Set to True if you wish to use an existing Storage Account to associate with the Function App. Default is false meaning Terraform module will create a new one | `bool` | `false` | no |
| <a name="input_existing_storage_account_name"></a> [existing\_storage\_account\_name](#input\_existing\_storage\_account\_name) | Name of existing Storage Account to associate with the Function App. | `string` | `""` | no |
| <a name="input_existing_storage_account_rg"></a> [existing\_storage\_account\_rg](#input\_existing\_storage\_account\_rg) | Resource Group of existing Storage Account to associate with the Function App. | `string` | `""` | no |
| <a name="input_existing_storage_private_dns_zone_ids"></a> [existing\_storage\_private\_dns\_zone\_ids](#input\_existing\_storage\_private\_dns\_zone\_ids) | Map of subresource name (blob/file/queue/table) to an existing Private DNS Zone ID to reuse instead of creating/linking a new one for that subresource, e.g. { blob = "...", file = "..." }. Only used when storage\_private\_endpoint\_enabled is true. | `map(string)` | `{}` | no |
| <a name="input_global_tags"></a> [global\_tags](#input\_global\_tags) | Populate any custom user defined tags from a map | `map(string)` | `{}` | no |
| <a name="input_location"></a> [location](#input\_location) | Cloud Connector Azure Region | `string` | n/a | yes |
| <a name="input_log_analytics_retention_days"></a> [log\_analytics\_retention\_days](#input\_log\_analytics\_retention\_days) | Log Analytics Workspace retention time in days. | `number` | `30` | no |
| <a name="input_log_analytics_sku"></a> [log\_analytics\_sku](#input\_log\_analytics\_sku) | Log Analytics Workspace SKU | `string` | `"PerGB2018"` | no |
| <a name="input_managed_identity_client_id"></a> [managed\_identity\_client\_id](#input\_managed\_identity\_client\_id) | Client ID of the User Managed Identity for Function App to utilize | `string` | n/a | yes |
| <a name="input_managed_identity_id"></a> [managed\_identity\_id](#input\_managed\_identity\_id) | ID of the User Managed Identity assigned to Function App | `string` | n/a | yes |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | A prefix to associate to all the CC VM module resources | `string` | `null` | no |
| <a name="input_path_to_scripts"></a> [path\_to\_scripts](#input\_path\_to\_scripts) | Path to script\_directory | `string` | `""` | no |
| <a name="input_resource_group"></a> [resource\_group](#input\_resource\_group) | Main Resource Group Name | `string` | n/a | yes |
| <a name="input_resource_tag"></a> [resource\_tag](#input\_resource\_tag) | A tag to associate to all the CC VM module resources | `string` | `null` | no |
| <a name="input_run_manual_sync"></a> [run\_manual\_sync](#input\_run\_manual\_sync) | Set to True if you would like terraform to run the manual sync operation to start the Function App after creation. The alternative is to navigate to the Function App on the Azure Portal UI or to manually invoke the script yourself. | `bool` | `true` | no |
| <a name="input_storage_network_rules_default_action"></a> [storage\_network\_rules\_default\_action](#input\_storage\_network\_rules\_default\_action) | Default action (Allow or Deny) for the Storage Account network rules created by this module. Only used when existing\_storage\_account is false. | `string` | `"Allow"` | no |
| <a name="input_storage_network_rules_ip_rules"></a> [storage\_network\_rules\_ip\_rules](#input\_storage\_network\_rules\_ip\_rules) | List of public IP or CIDR ranges to allow through the Storage Account network rules created by this module. Only used when existing\_storage\_account is false. | `list(string)` | `[]` | no |
| <a name="input_storage_network_rules_subnet_ids"></a> [storage\_network\_rules\_subnet\_ids](#input\_storage\_network\_rules\_subnet\_ids) | List of subnet IDs (with the Microsoft.Storage service endpoint enabled) to allow through the Storage Account network rules created by this module. Only used when existing\_storage\_account is false. | `list(string)` | `[]` | no |
| <a name="input_storage_private_endpoint_enabled"></a> [storage\_private\_endpoint\_enabled](#input\_storage\_private\_endpoint\_enabled) | Create Private Endpoints for the Storage Account if set to true - one per subresource in storage\_private\_endpoint\_subresource\_names, since Azure only permits a single subresource per Storage Account Private Endpoint. This does not by itself restrict public network access - also set storage\_public\_network\_access\_enabled to false and storage\_network\_rules\_default\_action to "Deny" for a fully private posture. | `bool` | `false` | no |
| <a name="input_storage_private_endpoint_subnet_id"></a> [storage\_private\_endpoint\_subnet\_id](#input\_storage\_private\_endpoint\_subnet\_id) | Subnet ID to deploy the Storage Account Private Endpoints into, e.g. module.network.private\_endpoint\_subnet\_id. Required when storage\_private\_endpoint\_enabled is true. | `string` | `null` | no |
| <a name="input_storage_private_endpoint_subresource_names"></a> [storage\_private\_endpoint\_subresource\_names](#input\_storage\_private\_endpoint\_subresource\_names) | Storage subresources to create a Private Endpoint for. AzureWebJobsStorage needs blob/queue/table; the Function App content share on a Premium/EP1 plan additionally needs file. Only used when storage\_private\_endpoint\_enabled is true. | `list(string)` | <pre>[<br/>  "blob",<br/>  "file",<br/>  "queue",<br/>  "table"<br/>]</pre> | no |
| <a name="input_storage_public_network_access_enabled"></a> [storage\_public\_network\_access\_enabled](#input\_storage\_public\_network\_access\_enabled) | Whether public network access is allowed on the Storage Account created by this module. Only used when existing\_storage\_account is false. | `bool` | `true` | no |
| <a name="input_terminate_unhealthy_instances"></a> [terminate\_unhealthy\_instances](#input\_terminate\_unhealthy\_instances) | Indicate whether detected unhealthy instances are terminated or not. | `bool` | `true` | no |
| <a name="input_upload_function_app_zip"></a> [upload\_function\_app\_zip](#input\_upload\_function\_app\_zip) | By default, this Terraform will create a new Storage Account/Container/Blob to upload the zip file. The function app will pull from the blobl url to run. Setting this value to false will prevent creation/upload of the blob file | `bool` | `true` | no |
| <a name="input_vmss_names"></a> [vmss\_names](#input\_vmss\_names) | Names of Virtual Machine Scale Sets for Function App to monitor provided as a list | `list(string)` | n/a | yes |
| <a name="input_vnet_id"></a> [vnet\_id](#input\_vnet\_id) | VNet ID to link the Storage Account privatelink Private DNS Zones to, e.g. module.network.virtual\_network\_id. Required when storage\_private\_endpoint\_enabled is true, for any subresource not already covered by existing\_storage\_private\_dns\_zone\_ids. | `string` | `null` | no |
| <a name="input_vnet_integration_enabled"></a> [vnet\_integration\_enabled](#input\_vnet\_integration\_enabled) | Integrate the Function App with a VNet subnet for regional (Swift) VNet Integration if set to true. Requires asp\_sku\_name to be set to a plan that supports VNet Integration (EP1) - see asp\_sku\_name description. | `bool` | `false` | no |
| <a name="input_vnet_integration_subnet_id"></a> [vnet\_integration\_subnet\_id](#input\_vnet\_integration\_subnet\_id) | Subnet ID, delegated to Microsoft.Web/serverFarms, that the Function App will integrate into, e.g. module.network.function\_app\_subnet\_id. Required when vnet\_integration\_enabled is true. | `string` | `null` | no |
| <a name="input_vnet_route_all_enabled"></a> [vnet\_route\_all\_enabled](#input\_vnet\_route\_all\_enabled) | Route all outbound Function App traffic (not just RFC1918-destined traffic) through the integrated VNet subnet. Only used when vnet\_integration\_enabled is true. RFC1918 traffic (including to Private Endpoints) is already routed over the VNet Integration by default without this. | `bool` | `false` | no |
| <a name="input_zscaler_cc_function_public_url"></a> [zscaler\_cc\_function\_public\_url](#input\_zscaler\_cc\_function\_public\_url) | Publicly accessible URL path where Function App can pull its zip file build from. This is only required when var.upload\_function\_app\_zip is set to false | `string` | `""` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_function_app_id"></a> [function\_app\_id](#output\_function\_app\_id) | Function App ID |
| <a name="output_function_app_name"></a> [function\_app\_name](#output\_function\_app\_name) | Function App ID |
| <a name="output_function_app_outbound_ip_address_list"></a> [function\_app\_outbound\_ip\_address\_list](#output\_function\_app\_outbound\_ip\_address\_list) | A list of outbound IP addresses used by the function |
| <a name="output_manual_sync_exit_status"></a> [manual\_sync\_exit\_status](#output\_manual\_sync\_exit\_status) | Exit status of the operation to manually sync the Azure Function App after deployment. |
| <a name="output_storage_account_id"></a> [storage\_account\_id](#output\_storage\_account\_id) | ID of the Storage Account (created by this module, or the existing/BYO account referenced by existing\_storage\_account\_name/existing\_storage\_account\_rg) |
| <a name="output_storage_account_name"></a> [storage\_account\_name](#output\_storage\_account\_name) | Name of the Storage Account |
| <a name="output_subscription_id"></a> [subscription\_id](#output\_subscription\_id) | Subscription ID. |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 0.13.7, < 2.0.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 3.108.0, <= 3.116 |
| <a name="requirement_local"></a> [local](#requirement\_local) | ~> 2.5.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | >= 3.108.0, <= 3.116 |
| <a name="provider_local"></a> [local](#provider\_local) | ~> 2.5.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [azurerm_application_insights.vmss_orchestration_app_insights](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_insights) | resource |
| [azurerm_linux_function_app.vmss_orchestration_app](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_function_app) | resource |
| [azurerm_linux_function_app.vmss_orchestration_app_with_manual_sync](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/linux_function_app) | resource |
| [azurerm_log_analytics_workspace.vmss_orchestration_log_analytics_workspace](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/log_analytics_workspace) | resource |
| [azurerm_private_dns_zone.storage](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone) | resource |
| [azurerm_private_dns_zone_virtual_network_link.storage](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_dns_zone_virtual_network_link) | resource |
| [azurerm_private_endpoint.storage](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint) | resource |
| [azurerm_service_plan.vmss_orchestration_app_service_plan](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/service_plan) | resource |
| [azurerm_storage_account.cc_function_storage_account](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) | resource |
| [azurerm_storage_blob.cc_function_storage_blob](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_blob) | resource |
| [azurerm_storage_container.cc_function_storage_container](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_container) | resource |
| [azurerm_storage_share.function_app_content](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_share) | resource |
| [azurerm_storage_account.existing_storage_account](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/storage_account) | data source |
| [azurerm_subscription.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subscription) | data source |
| [local_file.manual_sync_exist_status](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_asp_sku_name"></a> [asp\_sku\_name](#input\_asp\_sku\_name) | SKU Name for the App Service Plan. Recommended Y1 (flex consumption) for function app unless not supported by Azure region. Note: regional VNet Integration (vnet\_integration\_enabled) is only supported on EP1 among these options - Y1/FC1/B1 do not support it. | `string` | `"Y1"` | no |
| <a name="input_azure_vault_url"></a> [azure\_vault\_url](#input\_azure\_vault\_url) | Azure Vault URL | `string` | n/a | yes |
| <a name="input_cc_vm_prov_url"></a> [cc\_vm\_prov\_url](#input\_cc\_vm\_prov\_url) | Zscaler Cloud Connector Provisioning URL | `string` | n/a | yes |
| <a name="input_content_share_quota_gb"></a> [content\_share\_quota\_gb](#input\_content\_share\_quota\_gb) | Quota, in GB, for the Azure Files share this module creates and mounts as the Function App's content share (WEBSITE\_CONTENTSHARE). Only used when vnet\_integration\_enabled is true. | `number` | `100` | no |
| <a name="input_existing_log_analytics_workspace"></a> [existing\_log\_analytics\_workspace](#input\_existing\_log\_analytics\_workspace) | Set to True if you wish to use an existing Log Analytics Workspace to associate with the AppInsights Instance. Default is false meaning Terraform module will create a new one | `bool` | `false` | no |
| <a name="input_existing_log_analytics_workspace_id"></a> [existing\_log\_analytics\_workspace\_id](#input\_existing\_log\_analytics\_workspace\_id) | ID of existing Log Analytics Workspace to associate with the AppInsights Instance. | `string` | `""` | no |
| <a name="input_existing_storage_account"></a> [existing\_storage\_account](#input\_existing\_storage\_account) | Set to True if you wish to use an existing Storage Account to associate with the Function App. Default is false meaning Terraform module will create a new one | `bool` | `false` | no |
| <a name="input_existing_storage_account_name"></a> [existing\_storage\_account\_name](#input\_existing\_storage\_account\_name) | Name of existing Storage Account to associate with the Function App. | `string` | `""` | no |
| <a name="input_existing_storage_account_rg"></a> [existing\_storage\_account\_rg](#input\_existing\_storage\_account\_rg) | Resource Group of existing Storage Account to associate with the Function App. | `string` | `""` | no |
| <a name="input_existing_storage_private_dns_zone_ids"></a> [existing\_storage\_private\_dns\_zone\_ids](#input\_existing\_storage\_private\_dns\_zone\_ids) | Map of subresource name (blob/file/queue/table) to an existing Private DNS Zone ID to reuse instead of creating/linking a new one for that subresource, e.g. { blob = "...", file = "..." }. Only used when storage\_private\_endpoint\_enabled is true. | `map(string)` | `{}` | no |
| <a name="input_global_tags"></a> [global\_tags](#input\_global\_tags) | Populate any custom user defined tags from a map | `map(string)` | `{}` | no |
| <a name="input_location"></a> [location](#input\_location) | Cloud Connector Azure Region | `string` | n/a | yes |
| <a name="input_log_analytics_retention_days"></a> [log\_analytics\_retention\_days](#input\_log\_analytics\_retention\_days) | Log Analytics Workspace retention time in days. | `number` | `30` | no |
| <a name="input_log_analytics_sku"></a> [log\_analytics\_sku](#input\_log\_analytics\_sku) | Log Analytics Workspace SKU | `string` | `"PerGB2018"` | no |
| <a name="input_managed_identity_client_id"></a> [managed\_identity\_client\_id](#input\_managed\_identity\_client\_id) | Client ID of the User Managed Identity for Function App to utilize | `string` | n/a | yes |
| <a name="input_managed_identity_id"></a> [managed\_identity\_id](#input\_managed\_identity\_id) | ID of the User Managed Identity assigned to Function App | `string` | n/a | yes |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | A prefix to associate to all the CC VM module resources | `string` | `null` | no |
| <a name="input_path_to_scripts"></a> [path\_to\_scripts](#input\_path\_to\_scripts) | Path to script\_directory | `string` | `""` | no |
| <a name="input_resource_group"></a> [resource\_group](#input\_resource\_group) | Main Resource Group Name | `string` | n/a | yes |
| <a name="input_resource_tag"></a> [resource\_tag](#input\_resource\_tag) | A tag to associate to all the CC VM module resources | `string` | `null` | no |
| <a name="input_run_manual_sync"></a> [run\_manual\_sync](#input\_run\_manual\_sync) | Set to True if you would like terraform to run the manual sync operation to start the Function App after creation. The alternative is to navigate to the Function App on the Azure Portal UI or to manually invoke the script yourself. | `bool` | `true` | no |
| <a name="input_storage_network_rules_default_action"></a> [storage\_network\_rules\_default\_action](#input\_storage\_network\_rules\_default\_action) | Default action (Allow or Deny) for the Storage Account network rules created by this module. Only used when existing\_storage\_account is false. | `string` | `"Allow"` | no |
| <a name="input_storage_network_rules_ip_rules"></a> [storage\_network\_rules\_ip\_rules](#input\_storage\_network\_rules\_ip\_rules) | List of public IP or CIDR ranges to allow through the Storage Account network rules created by this module. Only used when existing\_storage\_account is false. | `list(string)` | `[]` | no |
| <a name="input_storage_network_rules_subnet_ids"></a> [storage\_network\_rules\_subnet\_ids](#input\_storage\_network\_rules\_subnet\_ids) | List of subnet IDs (with the Microsoft.Storage service endpoint enabled) to allow through the Storage Account network rules created by this module. Only used when existing\_storage\_account is false. | `list(string)` | `[]` | no |
| <a name="input_storage_private_endpoint_enabled"></a> [storage\_private\_endpoint\_enabled](#input\_storage\_private\_endpoint\_enabled) | Create Private Endpoints for the Storage Account if set to true - one per subresource in storage\_private\_endpoint\_subresource\_names, since Azure only permits a single subresource per Storage Account Private Endpoint. This does not by itself restrict public network access - also set storage\_public\_network\_access\_enabled to false and storage\_network\_rules\_default\_action to "Deny" for a fully private posture. | `bool` | `false` | no |
| <a name="input_storage_private_endpoint_subnet_id"></a> [storage\_private\_endpoint\_subnet\_id](#input\_storage\_private\_endpoint\_subnet\_id) | Subnet ID to deploy the Storage Account Private Endpoints into, e.g. module.network.private\_endpoint\_subnet\_id. Required when storage\_private\_endpoint\_enabled is true. | `string` | `null` | no |
| <a name="input_storage_private_endpoint_subresource_names"></a> [storage\_private\_endpoint\_subresource\_names](#input\_storage\_private\_endpoint\_subresource\_names) | Storage subresources to create a Private Endpoint for. AzureWebJobsStorage needs blob/queue/table; the Function App content share on a Premium/EP1 plan additionally needs file. Only used when storage\_private\_endpoint\_enabled is true. | `list(string)` | <pre>[<br/>  "blob",<br/>  "file",<br/>  "queue",<br/>  "table"<br/>]</pre> | no |
| <a name="input_storage_public_network_access_enabled"></a> [storage\_public\_network\_access\_enabled](#input\_storage\_public\_network\_access\_enabled) | Whether public network access is allowed on the Storage Account created by this module. Only used when existing\_storage\_account is false. | `bool` | `true` | no |
| <a name="input_terminate_unhealthy_instances"></a> [terminate\_unhealthy\_instances](#input\_terminate\_unhealthy\_instances) | Indicate whether detected unhealthy instances are terminated or not. | `bool` | `true` | no |
| <a name="input_upload_function_app_zip"></a> [upload\_function\_app\_zip](#input\_upload\_function\_app\_zip) | By default, this Terraform will create a new Storage Account/Container/Blob to upload the zip file. The function app will pull from the blobl url to run. Setting this value to false will prevent creation/upload of the blob file | `bool` | `true` | no |
| <a name="input_vmss_names"></a> [vmss\_names](#input\_vmss\_names) | Names of Virtual Machine Scale Sets for Function App to monitor provided as a list | `list(string)` | n/a | yes |
| <a name="input_vnet_id"></a> [vnet\_id](#input\_vnet\_id) | VNet ID to link the Storage Account privatelink Private DNS Zones to, e.g. module.network.virtual\_network\_id. Required when storage\_private\_endpoint\_enabled is true, for any subresource not already covered by existing\_storage\_private\_dns\_zone\_ids. | `string` | `null` | no |
| <a name="input_vnet_integration_enabled"></a> [vnet\_integration\_enabled](#input\_vnet\_integration\_enabled) | Integrate the Function App with a VNet subnet for regional (Swift) VNet Integration if set to true. Requires asp\_sku\_name to be set to a plan that supports VNet Integration (EP1) - see asp\_sku\_name description. | `bool` | `false` | no |
| <a name="input_vnet_integration_subnet_id"></a> [vnet\_integration\_subnet\_id](#input\_vnet\_integration\_subnet\_id) | Subnet ID, delegated to Microsoft.Web/serverFarms, that the Function App will integrate into, e.g. module.network.function\_app\_subnet\_id. Required when vnet\_integration\_enabled is true. | `string` | `null` | no |
| <a name="input_vnet_route_all_enabled"></a> [vnet\_route\_all\_enabled](#input\_vnet\_route\_all\_enabled) | Route all outbound Function App traffic (not just RFC1918-destined traffic) through the integrated VNet subnet. Only used when vnet\_integration\_enabled is true. RFC1918 traffic (including to Private Endpoints) is already routed over the VNet Integration by default without this. | `bool` | `false` | no |
| <a name="input_zscaler_cc_function_public_url"></a> [zscaler\_cc\_function\_public\_url](#input\_zscaler\_cc\_function\_public\_url) | Publicly accessible URL path where Function App can pull its zip file build from. This is only required when var.upload\_function\_app\_zip is set to false | `string` | `""` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_function_app_id"></a> [function\_app\_id](#output\_function\_app\_id) | Function App ID |
| <a name="output_function_app_name"></a> [function\_app\_name](#output\_function\_app\_name) | Function App ID |
| <a name="output_function_app_outbound_ip_address_list"></a> [function\_app\_outbound\_ip\_address\_list](#output\_function\_app\_outbound\_ip\_address\_list) | A list of outbound IP addresses used by the function |
| <a name="output_manual_sync_exit_status"></a> [manual\_sync\_exit\_status](#output\_manual\_sync\_exit\_status) | Exit status of the operation to manually sync the Azure Function App after deployment. |
| <a name="output_storage_account_id"></a> [storage\_account\_id](#output\_storage\_account\_id) | ID of the Storage Account (created by this module, or the existing/BYO account referenced by existing\_storage\_account\_name/existing\_storage\_account\_rg) |
| <a name="output_storage_account_name"></a> [storage\_account\_name](#output\_storage\_account\_name) | Name of the Storage Account |
| <a name="output_subscription_id"></a> [subscription\_id](#output\_subscription\_id) | Subscription ID. |
<!-- END_TF_DOCS -->