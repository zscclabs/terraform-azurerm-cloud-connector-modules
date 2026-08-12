################################################################################
# Reference inputs to obtain an existing User Managed Identity Resource
# to associate to Cloud Connector VM
################################################################################
data "azurerm_user_assigned_identity" "selected" {
  count               = var.existing_cc_vm_managed_identity ? 1 : 0
  name                = var.cc_vm_managed_identity_name
  resource_group_name = var.cc_vm_managed_identity_rg
}

################################################################################
# Optionally create a new User Managed Identity Resource to associate to
# Cloud Connector VM instead of referencing an existing one
################################################################################
resource "azurerm_user_assigned_identity" "cc_vm" {
  count               = var.existing_cc_vm_managed_identity ? 0 : 1
  name                = var.cc_vm_managed_identity_name
  resource_group_name = var.cc_vm_managed_identity_rg
  location            = var.location
  tags                = var.global_tags
}



################################################################################
# Reference inputs to obtain an existing User Managed Identity Resource
# to associate to to Function App.

# *Optional* - By default, CCs and Function will use the same Identity
################################################################################
data "azurerm_user_assigned_identity" "function_app_identity_selected" {
  count               = var.vmss_enabled && var.existing_function_app_managed_identity ? 1 : 0
  name                = var.function_app_managed_identity_name
  resource_group_name = var.function_app_managed_identity_rg
}

################################################################################
# Optionally create a new User Managed Identity Resource to associate to
# the VMSS Function App instead of referencing an existing one
################################################################################
resource "azurerm_user_assigned_identity" "function_app" {
  count               = var.vmss_enabled && !var.existing_function_app_managed_identity ? 1 : 0
  name                = var.function_app_managed_identity_name
  resource_group_name = var.function_app_managed_identity_rg
  location            = var.location
  tags                = var.global_tags
}



################################################################################
# Combine the data-source/resource pair for each identity into a single
# reference regardless of whether it was looked up or created
################################################################################
locals {
  managed_identity = var.existing_cc_vm_managed_identity ? data.azurerm_user_assigned_identity.selected[0] : azurerm_user_assigned_identity.cc_vm[0]

  function_app_managed_identity = var.vmss_enabled ? (
    var.existing_function_app_managed_identity ? data.azurerm_user_assigned_identity.function_app_identity_selected[0] : azurerm_user_assigned_identity.function_app[0]
  ) : null
}



################################################################################
# Optionally assign a Network Contributor (or custom) role to the CC VM
# Managed Identity at a caller-supplied scope (e.g. the Cloud Connector
# Resource Group or Subscription). Disabled by default since the identity
# may already carry this role assignment outside of Terraform.
################################################################################
resource "azurerm_role_assignment" "cc_vm_network_role" {
  count                = var.network_role_assignment_enabled ? 1 : 0
  scope                = var.network_role_assignment_scope
  role_definition_name = var.network_role_assignment_role_name
  principal_id         = local.managed_identity.principal_id
}
