resource "azurerm_log_analytics_workspace" "this" {
  name                = var.log_analytics_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_container_app_environment" "this" {
  name                       = var.name
  location                   = var.location
  resource_group_name        = var.resource_group_name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  infrastructure_subnet_id   = var.infrastructure_subnet_id

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
  }

  tags = var.tags
}

