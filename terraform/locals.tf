locals {
  # Get first two characters of the location
  location_short = substr(var.location, 0, 2)

  # Set standard name prefixes
  key_vault_prefix                      = "kv"
  load_testing_prefix                   = "alt"
  private_endpoint_prefix               = "pe"
  private_endpoint_connection_prefix   = "pec"
  private_endpoint_zone_group_conn_prefix = "pezgc"
  resource_group_prefix                 = "rg"
  user_assigned_managed_identity_prefix = "umi"

  # Settings for Azure Key Vault
  deployment_vm              = false
  deployment_template        = false
  disk_encryption            = false
  purge_protection           = false
  rbac_enabled               = true
  sku_name                   = "premium"
  soft_delete_retention_days = 7
  trusted_service_bypass     = "AzureServices"

  # Settings for Log Analytics Workspace
  law_retention_days = 30


  # Add required tags and merge them with the provided tags
  required_tags = {
    created_date = timestamp()
    created_by   = data.azurerm_client_config.identity_config.object_id
  }

  tags = merge(
    var.tags,
    local.required_tags
  )
}
