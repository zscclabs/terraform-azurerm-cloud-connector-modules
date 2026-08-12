variable "name_prefix" {
  type        = string
  description = "A prefix to associate to all the CC VM module resources"
  default     = null
}

variable "resource_tag" {
  type        = string
  description = "A tag to associate to all the CC VM module resources"
  default     = null
}

variable "global_tags" {
  type        = map(string)
  description = "Populate any custom user defined tags from a map"
  default     = {}
}

variable "resource_group" {
  type        = string
  description = "Main Resource Group Name"
}

variable "location" {
  type        = string
  description = "Cloud Connector Azure Region"
}

variable "upload_function_app_zip" {
  type        = bool
  description = "By default, this Terraform will create a new Storage Account/Container/Blob to upload the zip file. The function app will pull from the blobl url to run. Setting this value to false will prevent creation/upload of the blob file"
  default     = true
}

variable "zscaler_cc_function_public_url" {
  type        = string
  description = "Publicly accessible URL path where Function App can pull its zip file build from. This is only required when var.upload_function_app_zip is set to false"
  default     = ""
}

variable "cc_vm_prov_url" {
  type        = string
  description = "Zscaler Cloud Connector Provisioning URL"
}

variable "azure_vault_url" {
  type        = string
  description = "Azure Vault URL"
}

variable "terminate_unhealthy_instances" {
  type        = bool
  description = "Indicate whether detected unhealthy instances are terminated or not."
  default     = true
}

variable "vmss_names" {
  type        = list(string)
  description = "Names of Virtual Machine Scale Sets for Function App to monitor provided as a list"
}

variable "managed_identity_id" {
  type        = string
  description = "ID of the User Managed Identity assigned to Function App"
}

variable "managed_identity_client_id" {
  type        = string
  description = "Client ID of the User Managed Identity for Function App to utilize"
}

variable "existing_storage_account" {
  type        = bool
  description = "Set to True if you wish to use an existing Storage Account to associate with the Function App. Default is false meaning Terraform module will create a new one"
  default     = false
}

variable "existing_storage_account_name" {
  type        = string
  description = "Name of existing Storage Account to associate with the Function App."
  default     = ""
}

variable "existing_storage_account_rg" {
  type        = string
  description = "Resource Group of existing Storage Account to associate with the Function App."
  default     = ""
}

variable "existing_log_analytics_workspace" {
  type        = bool
  description = "Set to True if you wish to use an existing Log Analytics Workspace to associate with the AppInsights Instance. Default is false meaning Terraform module will create a new one"
  default     = false
}

variable "existing_log_analytics_workspace_id" {
  type        = string
  description = "ID of existing Log Analytics Workspace to associate with the AppInsights Instance."
  default     = ""
}

variable "log_analytics_sku" {
  type        = string
  description = "Log Analytics Workspace SKU"
  default     = "PerGB2018"
}

variable "log_analytics_retention_days" {
  type        = number
  description = "Log Analytics Workspace retention time in days."
  default     = 30
}

variable "run_manual_sync" {
  type        = bool
  description = "Set to True if you would like terraform to run the manual sync operation to start the Function App after creation. The alternative is to navigate to the Function App on the Azure Portal UI or to manually invoke the script yourself."
  default     = true
}

variable "path_to_scripts" {
  type        = string
  description = "Path to script_directory"
  default     = ""
}

variable "asp_sku_name" {
  type        = string
  description = "SKU Name for the App Service Plan. Recommended Y1 (flex consumption) for function app unless not supported by Azure region. Note: regional VNet Integration (vnet_integration_enabled) is only supported on EP1 among these options - Y1/FC1/B1 do not support it."
  default     = "Y1"
  validation {
    condition = (
      var.asp_sku_name == "Y1" ||
      var.asp_sku_name == "FC1" ||
      var.asp_sku_name == "EP1" ||
      var.asp_sku_name == "B1"
    )
    error_message = "Input asp_sku_name selected is not a valid/approved SKU Name."
  }
}

variable "storage_public_network_access_enabled" {
  type        = bool
  description = "Whether public network access is allowed on the Storage Account created by this module. Only used when existing_storage_account is false."
  default     = true
}

variable "storage_network_rules_default_action" {
  type        = string
  description = "Default action (Allow or Deny) for the Storage Account network rules created by this module. Only used when existing_storage_account is false."
  default     = "Allow"
  validation {
    condition = (
      var.storage_network_rules_default_action == "Allow" ||
      var.storage_network_rules_default_action == "Deny"
    )
    error_message = "Input storage_network_rules_default_action must be set to either Allow or Deny."
  }
}

variable "storage_network_rules_ip_rules" {
  type        = list(string)
  description = "List of public IP or CIDR ranges to allow through the Storage Account network rules created by this module. Only used when existing_storage_account is false."
  default     = []
}

variable "storage_network_rules_subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs (with the Microsoft.Storage service endpoint enabled) to allow through the Storage Account network rules created by this module. Only used when existing_storage_account is false."
  default     = []
}

variable "storage_private_endpoint_enabled" {
  type        = bool
  description = "Create Private Endpoints for the Storage Account if set to true - one per subresource in storage_private_endpoint_subresource_names, since Azure only permits a single subresource per Storage Account Private Endpoint. This does not by itself restrict public network access - also set storage_public_network_access_enabled to false and storage_network_rules_default_action to \"Deny\" for a fully private posture."
  default     = false
}

variable "storage_private_endpoint_subnet_id" {
  type        = string
  description = "Subnet ID to deploy the Storage Account Private Endpoints into, e.g. module.network.private_endpoint_subnet_id. Required when storage_private_endpoint_enabled is true."
  default     = null
}

variable "storage_private_endpoint_subresource_names" {
  type        = list(string)
  description = "Storage subresources to create a Private Endpoint for. AzureWebJobsStorage needs blob/queue/table; the Function App content share on a Premium/EP1 plan additionally needs file. Only used when storage_private_endpoint_enabled is true."
  default     = ["blob", "file", "queue", "table"]
  validation {
    condition     = length(setsubtract(var.storage_private_endpoint_subresource_names, ["blob", "file", "queue", "table"])) == 0
    error_message = "Input storage_private_endpoint_subresource_names may only contain blob, file, queue, and/or table."
  }
}

variable "vnet_id" {
  type        = string
  description = "VNet ID to link the Storage Account privatelink Private DNS Zones to, e.g. module.network.virtual_network_id. Required when storage_private_endpoint_enabled is true, for any subresource not already covered by existing_storage_private_dns_zone_ids."
  default     = null
}

variable "existing_storage_private_dns_zone_ids" {
  type        = map(string)
  description = "Map of subresource name (blob/file/queue/table) to an existing Private DNS Zone ID to reuse instead of creating/linking a new one for that subresource, e.g. { blob = \"...\", file = \"...\" }. Only used when storage_private_endpoint_enabled is true."
  default     = {}
}

variable "vnet_integration_enabled" {
  type        = bool
  description = "Integrate the Function App with a VNet subnet for regional (Swift) VNet Integration if set to true. Requires asp_sku_name to be set to a plan that supports VNet Integration (EP1) - see asp_sku_name description."
  default     = false
}

variable "vnet_integration_subnet_id" {
  type        = string
  description = "Subnet ID, delegated to Microsoft.Web/serverFarms, that the Function App will integrate into, e.g. module.network.function_app_subnet_id. Required when vnet_integration_enabled is true."
  default     = null
}

variable "vnet_route_all_enabled" {
  type        = bool
  description = "Route all outbound Function App traffic (not just RFC1918-destined traffic) through the integrated VNet subnet. Only used when vnet_integration_enabled is true. RFC1918 traffic (including to Private Endpoints) is already routed over the VNet Integration by default without this."
  default     = false
}

variable "content_share_quota_gb" {
  type        = number
  description = "Quota, in GB, for the Azure Files share this module creates and mounts as the Function App's content share (WEBSITE_CONTENTSHARE). Only used when vnet_integration_enabled is true."
  default     = 100
}
