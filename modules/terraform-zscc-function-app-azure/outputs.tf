output "function_app_id" {
  description = "Function App ID"
  value       = var.run_manual_sync ? azurerm_linux_function_app.vmss_orchestration_app_with_manual_sync[0].id : azurerm_linux_function_app.vmss_orchestration_app[0].id
}

output "function_app_name" {
  description = "Function App ID"
  value       = "${var.name_prefix}-ccvmss-${var.resource_tag}-function-app"
}

output "function_app_outbound_ip_address_list" {
  description = "A list of outbound IP addresses used by the function"
  value       = var.run_manual_sync ? azurerm_linux_function_app.vmss_orchestration_app_with_manual_sync[0].outbound_ip_address_list : azurerm_linux_function_app.vmss_orchestration_app[0].outbound_ip_address_list
}

output "manual_sync_exit_status" {
  description = "Exit status of the operation to manually sync the Azure Function App after deployment."
  value       = var.run_manual_sync && fileexists("${var.path_to_scripts}/exitstatus") ? chomp(data.local_file.manual_sync_exist_status[0].content) : "0"
}

output "subscription_id" {
  description = "Subscription ID."
  value       = data.azurerm_subscription.current.subscription_id
}

output "storage_account_id" {
  description = "ID of the Storage Account (created by this module, or the existing/BYO account referenced by existing_storage_account_name/existing_storage_account_rg)"
  value       = local.storage_account_id
}

output "storage_account_name" {
  description = "Name of the Storage Account"
  value       = local.storage_account_name
}
