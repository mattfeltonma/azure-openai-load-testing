output "load_testing_service_name" {
  value = azurerm_load_test.load-testing.name
}

output "load_testing_resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "client_id_secret_reference" {
  value = azurerm_key_vault_secret.kv-secrets["clientid"].id
}

output "client_secret_secret_reference" {
  value = azurerm_key_vault_secret.kv-secrets["clientsecret"].id
}

output "tenant_id_secret_reference" {
  value = azurerm_key_vault_secret.kv-secrets["tenantid"].id
}

output "load_testing_managed_identity_id" {
  value = azurerm_user_assigned_identity.umi.id
}