data "azurerm_client_config" "current" {}

################################################################################
# Derive the Key Vault name if one wasn't explicitly provided. Azure requires
# Key Vault names to be globally unique, 3-24 characters, alphanumeric/hyphen
# only - truncate to stay within that limit.
################################################################################
locals {
  key_vault_name = substr(coalesce(var.key_vault_name, lower("${var.name_prefix}-kv-${var.resource_tag}")), 0, 24)
}

################################################################################
# Optionally create a new Key Vault with RBAC authorization enabled
################################################################################
resource "azurerm_key_vault" "this" {
  count                         = var.existing_key_vault ? 0 : 1
  name                          = local.key_vault_name
  resource_group_name           = var.resource_group
  location                      = var.location
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = var.sku_name
  enable_rbac_authorization     = true
  purge_protection_enabled      = var.purge_protection_enabled
  soft_delete_retention_days    = var.soft_delete_retention_days
  public_network_access_enabled = var.public_network_access_enabled

  network_acls {
    default_action             = var.network_acls_default_action
    bypass                     = "AzureServices"
    ip_rules                   = var.network_acls_ip_rules
    virtual_network_subnet_ids = var.network_acls_subnet_ids
  }

  tags = var.global_tags
}

################################################################################
# Reference an existing Key Vault instead, when existing_key_vault is true.
# Secrets are assumed to already be populated in this case - this module
# never creates/manages secrets on a BYO Key Vault.
################################################################################
data "azurerm_key_vault" "existing" {
  count               = var.existing_key_vault ? 1 : 0
  name                = var.existing_key_vault_name
  resource_group_name = var.existing_key_vault_rg
}

locals {
  key_vault = var.existing_key_vault ? data.azurerm_key_vault.existing[0] : azurerm_key_vault.this[0]
}

################################################################################
# Optionally grant the Terraform-executing principal permission to manage
# secrets on the newly created Key Vault, since RBAC authorization means the
# deployer has no implicit access. Disabled by default - typically the
# deployer already holds sufficient RBAC (e.g. Owner/Contributor scoped
# broadly enough to include this) to create the vault itself.
################################################################################
resource "azurerm_role_assignment" "deployer_secrets_officer" {
  count                = var.assign_deployer_secrets_officer_role ? 1 : 0
  scope                = local.key_vault.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.terraform_deployer_object_id
}

################################################################################
# Create the Zscaler Cloud Connector credential secrets. Secret names match
# what the Cloud Connector provisioning agent expects to find in the vault.
# Skipped entirely for an existing/BYO Key Vault, or when secrets_enabled is
# false (e.g. the deployer lacks Key Vault RBAC permissions to write secrets -
# create the vault now, populate secrets later).
################################################################################
resource "azurerm_key_vault_secret" "api_key" {
  count        = !var.existing_key_vault && var.secrets_enabled ? 1 : 0
  name         = "api-key"
  value        = var.zscaler_api_key
  key_vault_id = azurerm_key_vault.this[0].id
  depends_on   = [azurerm_role_assignment.deployer_secrets_officer]
}

resource "azurerm_key_vault_secret" "username" {
  count        = !var.existing_key_vault && var.secrets_enabled ? 1 : 0
  name         = "username"
  value        = var.zscaler_username
  key_vault_id = azurerm_key_vault.this[0].id
  depends_on   = [azurerm_role_assignment.deployer_secrets_officer]
}

resource "azurerm_key_vault_secret" "password" {
  count        = !var.existing_key_vault && var.secrets_enabled ? 1 : 0
  name         = "password"
  value        = var.zscaler_password
  key_vault_id = azurerm_key_vault.this[0].id
  depends_on   = [azurerm_role_assignment.deployer_secrets_officer]
}

################################################################################
# Optionally grant the Cloud Connector Managed Identity read access to
# secrets via the built-in "Key Vault Secrets User" RBAC role.
################################################################################
resource "azurerm_role_assignment" "cc_secrets_reader" {
  count                = var.secrets_reader_principal_id != null ? 1 : 0
  scope                = local.key_vault.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.secrets_reader_principal_id
}

################################################################################
# Optionally create a Private DNS Zone for Key Vault Private Link and link it
# to the VNet. Skipped when existing_private_dns_zone_id is supplied (BYO
# zone, e.g. a hub-shared zone already linked elsewhere).
################################################################################
resource "azurerm_private_dns_zone" "key_vault" {
  count               = var.private_endpoint_enabled && var.existing_private_dns_zone_id == null ? 1 : 0
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group

  tags = var.global_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "key_vault" {
  count                 = var.private_endpoint_enabled && var.existing_private_dns_zone_id == null ? 1 : 0
  name                  = "${var.name_prefix}-kv-dns-link-${var.resource_tag}"
  resource_group_name   = var.resource_group
  private_dns_zone_name = azurerm_private_dns_zone.key_vault[0].name
  virtual_network_id    = var.vnet_id

  tags = var.global_tags
}

locals {
  key_vault_private_dns_zone_id = var.existing_private_dns_zone_id != null ? var.existing_private_dns_zone_id : try(azurerm_private_dns_zone.key_vault[0].id, null)
}

################################################################################
# Optionally create a Private Endpoint for the Key Vault. Targets local.key_vault
# so this works whether the vault was created above or referenced via
# existing_key_vault.
################################################################################
resource "azurerm_private_endpoint" "key_vault" {
  count               = var.private_endpoint_enabled ? 1 : 0
  name                = "${var.name_prefix}-kv-pe-${var.resource_tag}"
  resource_group_name = var.resource_group
  location            = var.location
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "${var.name_prefix}-kv-psc-${var.resource_tag}"
    private_connection_resource_id = local.key_vault.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "${var.name_prefix}-kv-dns-zone-group-${var.resource_tag}"
    private_dns_zone_ids = [local.key_vault_private_dns_zone_id]
  }

  tags = var.global_tags
}
