################################################################################
# Get current Subscription ID
################################################################################
data "azurerm_subscription" "current" {
}

################################################################################
# Create Function App Dependencies
################################################################################
# Create Storage Account to store Function App
resource "azurerm_storage_account" "cc_function_storage_account" {
  count                    = var.existing_storage_account ? 0 : 1
  name                     = "stccvmss${var.resource_tag}"
  resource_group_name      = var.resource_group
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  public_network_access_enabled = var.storage_public_network_access_enabled

  network_rules {
    default_action             = var.storage_network_rules_default_action
    bypass                     = ["AzureServices"]
    ip_rules                   = var.storage_network_rules_ip_rules
    virtual_network_subnet_ids = var.storage_network_rules_subnet_ids
  }
}

# Or use an existing storage account
data "azurerm_storage_account" "existing_storage_account" {
  count               = var.existing_storage_account ? 1 : 0
  name                = var.existing_storage_account_name
  resource_group_name = var.existing_storage_account_rg
}

# Create Private Storage Container to upload function zip file
resource "azurerm_storage_container" "cc_function_storage_container" {
  count                 = var.upload_function_app_zip ? 1 : 0
  name                  = "function-zip-container"
  storage_account_name  = local.storage_account_name
  container_access_type = "private"
}

# Create Storage Blob to store function zip file
resource "azurerm_storage_blob" "cc_function_storage_blob" {
  count                  = var.upload_function_app_zip ? 1 : 0
  name                   = "zscaler_cc_function_app.zip"
  storage_account_name   = local.storage_account_name
  storage_container_name = azurerm_storage_container.cc_function_storage_container[0].name
  type                   = "Block"
  source                 = "${path.module}/zscaler_cc_function_app.zip"
  content_md5            = filemd5("${path.module}/zscaler_cc_function_app.zip")
}

# Create the content share the Function App mounts when WEBSITE_CONTENTOVERVNET is set - the
# platform's own lazy auto-creation of this share is unreliable over a VNet-integrated/private
# storage account (observed hanging indefinitely rather than creating it), so manage it explicitly.
resource "azurerm_storage_share" "function_app_content" {
  count                = var.vnet_integration_enabled ? 1 : 0
  name                 = local.function_app_content_share_name
  storage_account_name = local.storage_account_name
  quota                = var.content_share_quota_gb
}

# Create App Service Plan
resource "azurerm_service_plan" "vmss_orchestration_app_service_plan" {
  name                = "${var.name_prefix}-ccvmss-${var.resource_tag}-app-service-plan"
  resource_group_name = var.resource_group
  location            = var.location
  os_type             = "Linux"
  sku_name            = var.asp_sku_name

  tags = var.global_tags
}

resource "azurerm_log_analytics_workspace" "vmss_orchestration_log_analytics_workspace" {
  count               = var.existing_log_analytics_workspace ? 0 : 1
  name                = "${var.name_prefix}-ccvmss-${var.resource_tag}-workspace"
  location            = var.location
  resource_group_name = var.resource_group
  sku                 = var.log_analytics_sku
  retention_in_days   = var.log_analytics_retention_days
}

locals {
  storage_account_name       = var.existing_storage_account ? data.azurerm_storage_account.existing_storage_account[0].name : azurerm_storage_account.cc_function_storage_account[0].name
  storage_account_id         = var.existing_storage_account ? data.azurerm_storage_account.existing_storage_account[0].id : azurerm_storage_account.cc_function_storage_account[0].id
  storage_account_access_key = var.existing_storage_account ? data.azurerm_storage_account.existing_storage_account[0].primary_access_key : azurerm_storage_account.cc_function_storage_account[0].primary_access_key
  log_analytics_workspace_id = var.existing_log_analytics_workspace ? var.existing_log_analytics_workspace_id : azurerm_log_analytics_workspace.vmss_orchestration_log_analytics_workspace[0].id

  # WEBSITE_CONTENTOVERVNET requires WEBSITE_CONTENTAZUREFILECONNECTIONSTRING/WEBSITE_CONTENTSHARE to
  # be set explicitly - the platform can't provision its own content share over a VNet-integrated app.
  storage_account_connection_string = "DefaultEndpointsProtocol=https;AccountName=${local.storage_account_name};AccountKey=${local.storage_account_access_key};EndpointSuffix=core.windows.net"
  function_app_content_share_name   = "${local.storage_account_name}-content"

  # The function app name (<=60 chars) can exceed the 32-char limit Azure Functions uses to derive
  # the host ID, risking host ID collisions/truncation - pin it explicitly instead of relying on
  # the platform's truncation. See: https://learn.microsoft.com/azure/azure-functions/storage-considerations#host-id
  function_app_host_id = trimsuffix(substr(lower(replace("${var.name_prefix}-ccvmss-${var.resource_tag}", "_", "-")), 0, 32), "-")
}


################################################################################
# Optionally create Private DNS Zones for Storage Account Private Link (one
# per requested subresource) and link them to the VNet. Skipped per-subresource
# when existing_storage_private_dns_zone_ids already supplies a zone id for it
# (BYO zone, e.g. a hub-shared zone already linked elsewhere).
################################################################################
locals {
  storage_subresource_zone_names = {
    blob  = "privatelink.blob.core.windows.net"
    file  = "privatelink.file.core.windows.net"
    queue = "privatelink.queue.core.windows.net"
    table = "privatelink.table.core.windows.net"
  }
  storage_pe_subresources                  = var.storage_private_endpoint_enabled ? toset(var.storage_private_endpoint_subresource_names) : toset([])
  storage_pe_subresources_needing_new_zone = setsubtract(local.storage_pe_subresources, keys(var.existing_storage_private_dns_zone_ids))
}

resource "azurerm_private_dns_zone" "storage" {
  for_each            = local.storage_pe_subresources_needing_new_zone
  name                = local.storage_subresource_zone_names[each.key]
  resource_group_name = var.resource_group

  tags = var.global_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "storage" {
  for_each              = local.storage_pe_subresources_needing_new_zone
  name                  = "${var.name_prefix}-${each.key}-dns-link-${var.resource_tag}"
  resource_group_name   = var.resource_group
  private_dns_zone_name = azurerm_private_dns_zone.storage[each.key].name
  virtual_network_id    = var.vnet_id

  tags = var.global_tags
}

locals {
  storage_private_dns_zone_ids = {
    for k in local.storage_pe_subresources :
    k => try(var.existing_storage_private_dns_zone_ids[k], azurerm_private_dns_zone.storage[k].id)
  }
}

################################################################################
# Optionally create a Private Endpoint per requested Storage Account
# subresource. Azure only permits a single subresource per Storage Account
# Private Endpoint, so this is for_each-driven rather than one PE with a list.
################################################################################
resource "azurerm_private_endpoint" "storage" {
  for_each            = local.storage_pe_subresources
  name                = "${var.name_prefix}-${each.key}-pe-${var.resource_tag}"
  resource_group_name = var.resource_group
  location            = var.location
  subnet_id           = var.storage_private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.name_prefix}-${each.key}-psc-${var.resource_tag}"
    private_connection_resource_id = local.storage_account_id
    subresource_names              = [each.key]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "${var.name_prefix}-${each.key}-dns-zone-group-${var.resource_tag}"
    private_dns_zone_ids = [local.storage_private_dns_zone_ids[each.key]]
  }

  tags = var.global_tags
}

# Create Application Insights resource
resource "azurerm_application_insights" "vmss_orchestration_app_insights" {
  name                = "${var.name_prefix}-ccvmss-${var.resource_tag}-app-insights"
  location            = var.location
  resource_group_name = var.resource_group
  workspace_id        = local.log_analytics_workspace_id
  application_type    = "web"

  tags = var.global_tags
}


################################################################################
# Create Function App
################################################################################
resource "azurerm_linux_function_app" "vmss_orchestration_app" {
  count               = var.run_manual_sync ? 0 : 1
  name                = "${var.name_prefix}-ccvmss-${var.resource_tag}-function-app"
  resource_group_name = var.resource_group
  location            = var.location

  storage_account_name       = local.storage_account_name
  storage_account_access_key = local.storage_account_access_key
  service_plan_id            = azurerm_service_plan.vmss_orchestration_app_service_plan.id
  virtual_network_subnet_id  = var.vnet_integration_enabled ? var.vnet_integration_subnet_id : null

  identity {
    type         = "UserAssigned"
    identity_ids = [var.managed_identity_id]
  }

  app_settings = merge(
    {
      "SUBSCRIPTION_ID"                              = data.azurerm_subscription.current.id
      "MANAGED_IDENTITY"                             = var.managed_identity_client_id
      "RESOURCE_GROUP"                               = var.resource_group
      "VMSS_NAME"                                    = jsonencode(var.vmss_names)
      "TERMINATE_UNHEALTHY_INSTANCES"                = var.terminate_unhealthy_instances
      "VAULT_URL"                                    = var.azure_vault_url
      "CC_URL"                                       = var.cc_vm_prov_url
      "APPLICATIONINSIGHTS_CONNECTION_STRING"        = azurerm_application_insights.vmss_orchestration_app_insights.connection_string
      "ApplicationInsightsAgent_EXTENSION_VERSION"   = "~3"
      "XDT_MicrosoftApplicationInsights_Mode"        = "recommended"
      "WEBSITE_RUN_FROM_PACKAGE"                     = var.upload_function_app_zip ? azurerm_storage_blob.cc_function_storage_blob[0].url : var.zscaler_cc_function_public_url
      "WEBSITE_RUN_FROM_PACKAGE_BLOB_MI_RESOURCE_ID" = var.managed_identity_id
      "AzureFunctionsWebHost__hostid"                = local.function_app_host_id
    },
    var.vnet_integration_enabled ? {
      "WEBSITE_CONTENTOVERVNET"                  = "1"
      "WEBSITE_CONTENTAZUREFILECONNECTIONSTRING" = local.storage_account_connection_string
      "WEBSITE_CONTENTSHARE"                     = local.function_app_content_share_name
    } : {}
  )

  site_config {
    application_stack {
      python_version = "3.11"
    }
    application_insights_connection_string = azurerm_application_insights.vmss_orchestration_app_insights.connection_string
    vnet_route_all_enabled                 = var.vnet_integration_enabled ? var.vnet_route_all_enabled : false
  }

  lifecycle {
    ignore_changes = [
      app_settings["APPLICATIONINSIGHTS_CONNECTION_STRING"],
    ]
  }

  depends_on = [azurerm_storage_share.function_app_content]

  tags = var.global_tags
}

resource "azurerm_linux_function_app" "vmss_orchestration_app_with_manual_sync" {
  count               = var.run_manual_sync ? 1 : 0
  name                = "${var.name_prefix}-ccvmss-${var.resource_tag}-function-app"
  resource_group_name = var.resource_group
  location            = var.location

  storage_account_name       = local.storage_account_name
  storage_account_access_key = local.storage_account_access_key
  service_plan_id            = azurerm_service_plan.vmss_orchestration_app_service_plan.id
  virtual_network_subnet_id  = var.vnet_integration_enabled ? var.vnet_integration_subnet_id : null

  identity {
    type         = "UserAssigned"
    identity_ids = [var.managed_identity_id]
  }

  app_settings = merge(
    {
      "SUBSCRIPTION_ID"                              = data.azurerm_subscription.current.id
      "MANAGED_IDENTITY"                             = var.managed_identity_client_id
      "RESOURCE_GROUP"                               = var.resource_group
      "VMSS_NAME"                                    = jsonencode(var.vmss_names)
      "TERMINATE_UNHEALTHY_INSTANCES"                = var.terminate_unhealthy_instances
      "VAULT_URL"                                    = var.azure_vault_url
      "CC_URL"                                       = var.cc_vm_prov_url
      "APPLICATIONINSIGHTS_CONNECTION_STRING"        = azurerm_application_insights.vmss_orchestration_app_insights.connection_string
      "ApplicationInsightsAgent_EXTENSION_VERSION"   = "~3"
      "XDT_MicrosoftApplicationInsights_Mode"        = "recommended"
      "WEBSITE_RUN_FROM_PACKAGE"                     = var.upload_function_app_zip ? azurerm_storage_blob.cc_function_storage_blob[0].url : var.zscaler_cc_function_public_url
      "WEBSITE_RUN_FROM_PACKAGE_BLOB_MI_RESOURCE_ID" = var.managed_identity_id
      "AzureFunctionsWebHost__hostid"                = local.function_app_host_id
    },
    var.vnet_integration_enabled ? {
      "WEBSITE_CONTENTOVERVNET"                  = "1"
      "WEBSITE_CONTENTAZUREFILECONNECTIONSTRING" = local.storage_account_connection_string
      "WEBSITE_CONTENTSHARE"                     = local.function_app_content_share_name
    } : {}
  )

  site_config {
    application_stack {
      python_version = "3.11"
    }
    application_insights_connection_string = azurerm_application_insights.vmss_orchestration_app_insights.connection_string
    vnet_route_all_enabled                 = var.vnet_integration_enabled ? var.vnet_route_all_enabled : false
  }

  lifecycle {
    ignore_changes = [
      app_settings["APPLICATIONINSIGHTS_CONNECTION_STRING"],
    ]
  }

  depends_on = [azurerm_storage_share.function_app_content]

  tags = var.global_tags

  provisioner "local-exec" {
    command = "${var.path_to_scripts}/manual_sync.sh ${data.azurerm_subscription.current.subscription_id} ${var.resource_group} ${azurerm_linux_function_app.vmss_orchestration_app_with_manual_sync[0].name} 2>${var.path_to_scripts}/stderr >${var.path_to_scripts}/stdout; echo $? >${var.path_to_scripts}/exitstatus"
  }
}

data "local_file" "manual_sync_exist_status" {
  count    = var.run_manual_sync && fileexists("${var.path_to_scripts}/exitstatus") ? 1 : 0
  filename = "${var.path_to_scripts}/exitstatus"
  depends_on = [
    azurerm_linux_function_app.vmss_orchestration_app_with_manual_sync[0]
  ]
}
