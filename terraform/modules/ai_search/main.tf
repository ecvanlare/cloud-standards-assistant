resource "azurerm_search_service" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.sku
  replica_count       = var.replica_count
  partition_count     = var.partition_count

  local_authentication_enabled = false

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

