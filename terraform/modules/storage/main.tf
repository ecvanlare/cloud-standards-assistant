resource "azurerm_storage_account" "this" {
  name                     = var.name
  location                 = var.location
  resource_group_name      = var.resource_group_name
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  min_tls_version          = "TLS1_2"

  blob_properties {
    versioning_enabled = false
  }

  tags = var.tags
}

resource "azurerm_storage_container" "corpus" {
  name                  = var.corpus_container_name
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}

