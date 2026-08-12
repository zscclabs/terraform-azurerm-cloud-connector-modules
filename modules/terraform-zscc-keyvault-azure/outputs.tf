output "key_vault_id" {
  description = "ID of the Key Vault (created by this module, or the existing/BYO Key Vault referenced by existing_key_vault_name/existing_key_vault_rg)"
  value       = local.key_vault.id
}

output "key_vault_uri" {
  description = "URI of the Key Vault. Feed this into the azure_vault_url variable consumed by the Cloud Connector VM/VMSS userdata and Function App"
  value       = local.key_vault.vault_uri
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = local.key_vault.name
}

output "private_endpoint_id" {
  description = "ID of the Key Vault Private Endpoint (empty string if private_endpoint_enabled is false)"
  value       = var.private_endpoint_enabled ? azurerm_private_endpoint.key_vault[0].id : ""
}

output "private_endpoint_ip_address" {
  description = "Private IP address assigned to the Key Vault Private Endpoint (empty string if private_endpoint_enabled is false)"
  value       = var.private_endpoint_enabled ? azurerm_private_endpoint.key_vault[0].private_service_connection[0].private_ip_address : ""
}
