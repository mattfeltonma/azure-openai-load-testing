# Generate random string
resource "random_string" "unique" {
  length      = 3
  min_numeric = 3
  numeric     = true
  special     = false
  lower       = true
  upper       = false
}

# Create resource group
resource "azurerm_resource_group" "rg" {

  name     = "${local.resource_group_prefix}${var.purpose}${local.location_short}${random_string.unique.result}"
  location = var.location

  tags = local.tags

  lifecycle {
    ignore_changes = [
      tags["created_date"],
      tags["created_by"]
    ]
  }
}

# Create Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "law" {
  name                = "${local.resource_group_prefix}${var.purpose}${local.location_short}${random_string.unique.result}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = local.law_retention_days

  tags = local.tags

  lifecycle {
    ignore_changes = [
      tags["created_date"],
      tags["created_by"]
    ]
  }
}

# Create user-assigned managed identity for Azure Load Testing service instance
resource "azurerm_user_assigned_identity" "umi" {
  name                = "${local.user_assigned_managed_identity_prefix}${var.purpose}${local.location_short}${random_string.unique.result}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  tags = local.tags

  lifecycle {
    ignore_changes = [
      tags["created_date"],
      tags["created_by"]
    ]
  }
}

# Create Azure Key Vault and diagnostic settings for Key Vault
resource "azurerm_key_vault" "kv" {

  depends_on = [
    azurerm_log_analytics_workspace.law,
    azurerm_user_assigned_identity.umi
  ]


  name                = "${local.key_vault_prefix}${var.purpose}${local.location_short}${random_string.unique.result}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  sku_name  = local.sku_name
  tenant_id = data.azurerm_subscription.current.tenant_id

  enabled_for_deployment          = local.deployment_vm
  enabled_for_template_deployment = local.deployment_template
  enable_rbac_authorization       = local.rbac_enabled

  enabled_for_disk_encryption = local.disk_encryption
  soft_delete_retention_days  = local.soft_delete_retention_days
  purge_protection_enabled    = local.purge_protection

  network_acls {
    default_action = var.key_vault_default_action
    bypass         = local.trusted_service_bypass
    ip_rules       = []
  }
  tags = var.tags

  lifecycle {
    ignore_changes = [
      tags["created_date"],
      tags["created_by"]
    ]
  }
}

resource "azurerm_monitor_diagnostic_setting" "kv-diag-base" {
  depends_on = [
    azurerm_key_vault.kv
  ]

  name                       = "diag-base"
  target_resource_id         = azurerm_key_vault.kv.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_log {
    category = "AuditEvent"
  }

  enabled_log {
    category = "AzurePolicyEvaluationDetails"
  }

  metric {
    category = "AllMetrics"
  }
}

# Create Azure RBAC assignment for user that will be Key Vault Administrator
resource "azurerm_role_assignment" "assign-admin" {
  depends_on = [
    azurerm_monitor_diagnostic_setting.diag-base
  ]
  name                 = uuidv5("dns", "${azurerm_key_vault.kv.name}${var.key_vault_administrator}")
  scope                = "/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/${azurerm_resource_group.rg.name}/providers/Microsoft.KeyVault/vaults/${azurerm_key_vault.kv.name}"
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.key_vault_administrator
}

# Create Azure RBAC assignment for user-assigned managed identity that will be used by Azure Load Testing service instance
resource "azurerm_role_assignment" "assign-umi" {
  depends_on = [
    azurerm_role_assignment.assign-admin
  ]
  name                 = uuidv5("dns", "${azurerm_user_assigned_identity.umi.name}${var.key_vault_administrator}")
  scope                = "/subscriptions/${data.azurerm_subscription.current.subscription_id}/resourceGroups/${azurerm_resource_group.rg.name}/providers/Microsoft.KeyVault/vaults/${azurerm_key_vault.kv.name}"
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.umi.principal_id
}

# Create secrets for client id, client secret, and tenant id
resource "azurerm_key_vault_secret" "kv-secrets" {
  depends_on = [
    azurerm_key_vault.kv,
    azurerm_role_assignment.assign-umi
  ]

  for_each = var.secrets

  name = each.key
  value = each.value
  key_vault_id = azurerm_key_vault.kv.id

  tags = local.tags

  lifecycle {
    ignore_changes = [
      tags["created_date"],
      tags["created_by"]
    ]
  }
}

# Create Private Endpoint for Azure Key Vault instance
resource "azurerm_private_endpoint" "kv-pe" {
  depends_on = [
    azurerm_key_vault_secret.kv-secrets
  ]

  name                = "${local.private_endpoint_prefix}${var.purpose}${local.location_short}${random_string.unique.result}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  subnet_id = var.subnet_id_pe

  private_service_connection {
    name                           = "${local.private_endpoint_connection_prefix}${azurerm_key_vault.kv.name}${"vault"}"
    private_connection_resource_id = azurerm_key_vault.kv.id
    subresource_names = [ "vault" ]
    is_manual_connection            = false
  }

  private_dns_zone_group {
    name = "${local.private_endpoint_zone_group_conn_prefix}${azurerm_key_vault.kv.name}"
    private_dns_zone_ids = [
      var.key_vault_private_dns_zone_id
    ]
  }
  tags = local.tags

  lifecycle {
    ignore_changes = [
      tags["created_date"],
      tags["created_by"]
    ]
  }
}

# Create Azure Load Testing service instance
resource "azurerm_load_test" "load-testing" {
  depends_on = [
    azurerm_user_assigned_identity.umi,
    azurerm_role_assignment.assign-umi,
    azurerm_private_endpoint.kv-pe
  ]

  name                = "${local.load_testing_prefix}${var.purpose}${local.location_short}${random_string.unique.result}"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  description = "Azure Load Testing service instance for ${var.purpose} in ${var.location}"

  identity {
    type = "UserAssigned"
    identity_ids = [
      azurerm_user_assigned_identity.umi.id
    ]
  }

  tags = local.tags

  lifecycle {
    ignore_changes = [
      tags["created_date"],
      tags["created_by"]
    ]
  }

}

resource "azurerm_monitor_diagnostic_setting" "load-testing-diag-base" {
  depends_on = [
    azurerm_load_test.load-testing
  ]

  name                       = "diag-base"
  target_resource_id         = azurerm_load_test.load-testing.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  enabled_log {
    category = "AzureLoadTestingOperations"
  }

  metric {
    category = "AllMetrics"
  }
}