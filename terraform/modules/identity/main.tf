resource "azurerm_user_assigned_identity" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_role_assignment" "storage_blob_data_contributor" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.this.principal_id
}

resource "azurerm_role_assignment" "key_vault_secrets_user" {
  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.this.principal_id
}

resource "azurerm_role_assignment" "cognitive_services_user" {
  scope                = var.cognitive_account_id
  role_definition_name = "Cognitive Services User"
  principal_id         = azurerm_user_assigned_identity.this.principal_id
}

resource "azurerm_role_assignment" "search_index_data_contributor" {
  scope                = var.search_service_id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = azurerm_user_assigned_identity.this.principal_id
}

resource "azurerm_role_assignment" "search_service_contributor" {
  scope                = var.search_service_id
  role_definition_name = "Search Service Contributor"
  principal_id         = azurerm_user_assigned_identity.this.principal_id
}

