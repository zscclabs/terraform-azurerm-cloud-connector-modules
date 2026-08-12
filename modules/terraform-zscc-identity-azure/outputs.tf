output "managed_identity_id" {
  description = "User Managed Identity ID"
  value       = local.managed_identity.id
}

output "managed_identity_client_id" {
  description = "The Client ID of the User Assigned Identity"
  value       = local.managed_identity.client_id
}

output "managed_identity_principal_id" {
  description = "The Object(Principal) ID of the User Assigned Identity"
  value       = local.managed_identity.principal_id
}

#Function app Managed Identity outputs
output "function_app_managed_identity_id" {
  description = "User Managed Identity ID dedicated for VMSS Function App"
  value       = local.function_app_managed_identity != null ? local.function_app_managed_identity.id : null
}

output "function_app_managed_identity_client_id" {
  description = "The Client ID of the User Assigned Identity dedicated for VMSS Function App"
  value       = local.function_app_managed_identity != null ? local.function_app_managed_identity.client_id : null
}

output "function_app_managed_identity_principal_id" {
  description = "The Object(Principal) ID of the User Assigned Identity dedicated for VMSS Function App"
  value       = local.function_app_managed_identity != null ? local.function_app_managed_identity.principal_id : null
}
