resource "azurerm_user_assigned_identity" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

data "azurerm_client_config" "current" {}

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

# Whoever applies, plus operators, so a local apply and a CI apply grant the same set.
locals {
  operator_ids = toset(distinct(concat([data.azurerm_client_config.current.object_id], var.operator_object_ids)))

  operator_roles = {
    search_index_data_contributor = { scope = var.search_service_id, role = "Search Index Data Contributor" }
    search_service_contributor    = { scope = var.search_service_id, role = "Search Service Contributor" }
    foundry_user                  = { scope = var.cognitive_account_id, role = "Foundry User" }
    storage_blob_data_contributor = { scope = var.storage_account_id, role = "Storage Blob Data Contributor" }
  }

  # Keys hash the object ID so plan and apply logs (public CI) do not print it.
  operator_assignments = {
    for pair in setproduct(local.operator_ids, keys(local.operator_roles)) :
    "${substr(sha256(pair[0]), 0, 12)}-${pair[1]}" => {
      principal_id = pair[0]
      scope        = local.operator_roles[pair[1]].scope
      role         = local.operator_roles[pair[1]].role
    }
  }
}

resource "azurerm_role_assignment" "operator" {
  for_each = local.operator_assignments

  scope                = each.value.scope
  role_definition_name = each.value.role
  principal_id         = each.value.principal_id
}

resource "azurerm_role_assignment" "search_storage_blob_data_reader" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = var.search_principal_id
}

resource "azurerm_role_assignment" "search_cognitive_services_user" {
  scope                = var.cognitive_account_id
  role_definition_name = "Cognitive Services User"
  principal_id         = var.search_principal_id
}

resource "azurerm_role_assignment" "foundry_project_search_index_data_contributor" {
  scope                = var.search_service_id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = var.foundry_project_principal_id
}

resource "azurerm_role_assignment" "foundry_project_search_service_contributor" {
  scope                = var.search_service_id
  role_definition_name = "Search Service Contributor"
  principal_id         = var.foundry_project_principal_id
}

resource "azurerm_role_assignment" "foundry_account_search_index_data_contributor" {
  scope                = var.search_service_id
  role_definition_name = "Search Index Data Contributor"
  principal_id         = var.foundry_account_principal_id
}

resource "azurerm_role_assignment" "foundry_project_foundry_user" {
  scope                = var.cognitive_account_id
  role_definition_name = "Foundry User"
  principal_id         = var.foundry_project_principal_id
}

# Datasets / Evaluations upload blobs via the project MI on the corpus storage connection.
resource "azurerm_role_assignment" "foundry_project_storage_blob_data_contributor" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.foundry_project_principal_id
}

