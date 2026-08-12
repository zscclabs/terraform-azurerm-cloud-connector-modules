variable "cc_vm_managed_identity_name" {
  type        = string
  description = "Azure Managed Identity name to attach to the CC VM. E.g zspreview-66117-mi"
}

variable "cc_vm_managed_identity_rg" {
  type        = string
  description = "Resource Group of the Azure Managed Identity name to attach to the CC VM. E.g. edgeconnector_rg_1"
}

variable "function_app_managed_identity_name" {
  type        = string
  description = "Azure Managed Identity name to attach to the Function App. E.g zspreview-66117-mi"
  default     = ""
}

variable "function_app_managed_identity_rg" {
  type        = string
  description = "Resource Group of the Azure Managed Identity name to attach to the Function App. E.g. edgeconnector_rg_1"
  default     = ""
}

variable "vmss_enabled" {
  type        = bool
  description = "Default is false non non-vmss deployments. If true, module will do a data lookup (or create, per existing_function_app_managed_identity) for an additional managed identity resource for Function App in the same subscription"
  default     = false
}

variable "existing_cc_vm_managed_identity" {
  type        = bool
  description = "Set to true (default) to do a data lookup of an existing Managed Identity named by cc_vm_managed_identity_name/cc_vm_managed_identity_rg. Set to false to have this module create a new Managed Identity with that name/resource group instead."
  default     = true
}

variable "existing_function_app_managed_identity" {
  type        = bool
  description = "Set to true (default) to do a data lookup of an existing Managed Identity named by function_app_managed_identity_name/function_app_managed_identity_rg. Set to false to have this module create a new Managed Identity with that name/resource group instead. Only relevant when vmss_enabled is true."
  default     = true
}

variable "location" {
  type        = string
  description = "Azure region to create the Managed Identity/Identities in. Only required when existing_cc_vm_managed_identity and/or existing_function_app_managed_identity are set to false."
  default     = null
}

variable "global_tags" {
  type        = map(string)
  description = "Map of tags applied to any Managed Identity created by this module. Not applied when referencing an existing Managed Identity via data source."
  default     = {}
}

variable "network_role_assignment_enabled" {
  type        = bool
  description = "Set to true to have this module assign network_role_assignment_role_name to the CC VM Managed Identity at network_role_assignment_scope. Default is false, since the identity may already carry this role assignment outside of Terraform."
  default     = false
}

variable "network_role_assignment_scope" {
  type        = string
  description = "Resource ID (Subscription or Resource Group) to scope the network_role_assignment_role_name role assignment to. Required when network_role_assignment_enabled is true. E.g. a sibling network module's resource_group_id output."
  default     = null
}

variable "network_role_assignment_role_name" {
  type        = string
  description = "Role name to assign to the CC VM Managed Identity when network_role_assignment_enabled is true. Defaults to the built-in Network Contributor role; override with a custom role name if using a minimally-scoped custom role (minimum requirement: Microsoft.Network/networkInterfaces/read)."
  default     = "Network Contributor"
}
