variable "name_prefix" {
  type        = string
  description = "A prefix to associate to all the keyvault module resources"
  default     = null
}

variable "resource_tag" {
  type        = string
  description = "A tag to associate to all the keyvault module resources"
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

variable "existing_key_vault" {
  type        = bool
  description = "Set to true if you wish to use an existing Key Vault instead of creating a new one. Default is false, meaning this module will create a new Key Vault."
  default     = false
}

variable "existing_key_vault_name" {
  type        = string
  description = "Name of existing Key Vault. Required when existing_key_vault is true."
  default     = ""
}

variable "existing_key_vault_rg" {
  type        = string
  description = "Resource Group of existing Key Vault. Required when existing_key_vault is true."
  default     = ""
}

variable "key_vault_name" {
  type        = string
  description = "Explicit name for the Key Vault created by this module. If left null, a name is derived from name_prefix and resource_tag and truncated to Azure's 24 character Key Vault name limit. Only used when existing_key_vault is false."
  default     = null
}

variable "sku_name" {
  type        = string
  description = "SKU for the Key Vault created by this module. Only used when existing_key_vault is false."
  default     = "standard"
  validation {
    condition = (
      var.sku_name == "standard" ||
      var.sku_name == "premium"
    )
    error_message = "Input sku_name must be set to either standard or premium."
  }
}

variable "purge_protection_enabled" {
  type        = bool
  description = "Whether purge protection is enabled on the Key Vault created by this module. Default is false to allow examples/testing to be freely destroyed and recreated (e.g. via the zsec wrapper script); set to true for production deployments. Only used when existing_key_vault is false."
  default     = false
}

variable "soft_delete_retention_days" {
  type        = number
  description = "Number of days that items should be retained for once soft-deleted on the Key Vault created by this module. Only used when existing_key_vault is false."
  default     = 90
  validation {
    condition = (
      var.soft_delete_retention_days >= 7 &&
      var.soft_delete_retention_days <= 90
    )
    error_message = "Input soft_delete_retention_days must be a number between 7 and 90."
  }
}

variable "public_network_access_enabled" {
  type        = bool
  description = "Whether public network access is allowed on the Key Vault created by this module. Only used when existing_key_vault is false."
  default     = true
}

variable "network_acls_default_action" {
  type        = string
  description = "Default action (Allow or Deny) for the Key Vault network ACLs created by this module. Only used when existing_key_vault is false."
  default     = "Allow"
  validation {
    condition = (
      var.network_acls_default_action == "Allow" ||
      var.network_acls_default_action == "Deny"
    )
    error_message = "Input network_acls_default_action must be set to either Allow or Deny."
  }
}

variable "network_acls_ip_rules" {
  type        = list(string)
  description = "List of IP or CIDR ranges to allow through the Key Vault network ACLs created by this module. Only used when existing_key_vault is false."
  default     = []
}

variable "network_acls_subnet_ids" {
  type        = list(string)
  description = "List of subnet IDs (with the Microsoft.KeyVault service endpoint enabled) to allow through the Key Vault network ACLs created by this module. Only used when existing_key_vault is false."
  default     = []
}

variable "secrets_enabled" {
  type        = bool
  description = "Whether this module writes the zscaler_api_key/zscaler_username/zscaler_password secrets into the Key Vault it creates. Default is true. Set to false to create the vault (and optionally its Private Endpoint/role assignments) without writing secret values - e.g. when the deployer lacks Key Vault RBAC permissions to write secrets and they will be populated later by someone who does. Only used when existing_key_vault is false; BYO Key Vaults never have secrets written by this module regardless of this setting."
  default     = true
}

variable "zscaler_api_key" {
  type        = string
  description = "Zscaler Cloud Connector API Key (from the API Key Management page on the Zscaler Admin Console), stored as the 'api-key' secret. Required when existing_key_vault is false and secrets_enabled is true; left null otherwise."
  default     = null
  sensitive   = true
}

variable "zscaler_username" {
  type        = string
  description = "Zscaler Cloud Connector provisioning username, stored as the 'username' secret. Required when existing_key_vault is false and secrets_enabled is true; left null otherwise."
  default     = null
  sensitive   = true
}

variable "zscaler_password" {
  type        = string
  description = "Zscaler Cloud Connector provisioning password, stored as the 'password' secret. Required when existing_key_vault is false and secrets_enabled is true; left null otherwise."
  default     = null
  sensitive   = true
}

variable "secrets_reader_principal_id" {
  type        = string
  description = "Principal (Object) ID of the Cloud Connector Managed Identity to grant the built-in 'Key Vault Secrets User' RBAC role on this Key Vault. Leave null (default) to skip the role assignment, e.g. if access is already granted outside of Terraform."
  default     = null
}

variable "assign_deployer_secrets_officer_role" {
  type        = bool
  description = "Set to true to have this module grant the built-in 'Key Vault Secrets Officer' role to terraform_deployer_object_id, so the Terraform-executing principal can write the zscaler_api_key/zscaler_username/zscaler_password secrets without already holding that permission on the Key Vault. Default is false. Only useful when secrets_enabled is true (or you plan to manage secrets manually afterward) - and itself requires the deployer to already hold Microsoft.Authorization/roleAssignments/write, which not every principal has."
  default     = false
}

variable "terraform_deployer_object_id" {
  type        = string
  description = "Object ID of the principal running Terraform (user, service principal, or managed identity). Required when assign_deployer_secrets_officer_role is true."
  default     = null
}

variable "private_endpoint_enabled" {
  type        = bool
  description = "Create a Private Endpoint for the Key Vault if set to true. This does not by itself restrict public network access - also set public_network_access_enabled to false and network_acls_default_action to \"Deny\" for a fully private posture."
  default     = false
}

variable "private_endpoint_subnet_id" {
  type        = string
  description = "Subnet ID to deploy the Key Vault Private Endpoint into, e.g. module.network.private_endpoint_subnet_id. Required when private_endpoint_enabled is true."
  default     = null
}

variable "vnet_id" {
  type        = string
  description = "VNet ID to link the privatelink.vaultcore.azure.net Private DNS Zone to, e.g. module.network.virtual_network_id. Required when private_endpoint_enabled is true and existing_private_dns_zone_id is not set."
  default     = null
}

variable "existing_private_dns_zone_id" {
  type        = string
  description = "ID of an existing privatelink.vaultcore.azure.net Private DNS Zone to reuse (e.g. a hub-shared zone) instead of creating/linking a new one. Only used when private_endpoint_enabled is true."
  default     = null
}
