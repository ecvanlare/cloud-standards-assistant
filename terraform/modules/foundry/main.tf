resource "azurerm_cognitive_account" "this" {
  name                          = var.name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  kind                          = "AIServices"
  sku_name                      = var.sku_name
  custom_subdomain_name         = var.custom_subdomain_name
  project_management_enabled    = true
  public_network_access_enabled = true
  local_auth_enabled            = false

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

resource "azurerm_cognitive_account_project" "this" {
  name                 = var.project_name
  cognitive_account_id = azurerm_cognitive_account.this.id
  location             = var.location
  display_name         = var.project_name
  description          = "Cloud Standards Assistant Foundry project"

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

resource "azurerm_cognitive_deployment" "chat" {
  name                 = var.chat_deployment_name
  cognitive_account_id = azurerm_cognitive_account.this.id

  model {
    format  = "OpenAI"
    name    = var.chat_model_name
    version = var.chat_model_version
  }

  sku {
    name     = "GlobalStandard"
    capacity = var.chat_capacity
  }
}

resource "azurerm_cognitive_deployment" "embedding" {
  name                 = var.embedding_deployment_name
  cognitive_account_id = azurerm_cognitive_account.this.id

  model {
    format  = "OpenAI"
    name    = var.embedding_model_name
    version = var.embedding_model_version
  }

  sku {
    name     = "GlobalStandard"
    capacity = var.embedding_capacity
  }
}

