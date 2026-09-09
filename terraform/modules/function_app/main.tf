resource "azurerm_storage_account" "this" {
  name                     = var.storage_account_name
  location                 = var.location
  resource_group_name      = var.resource_group_name
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  min_tls_version          = "TLS1_2"
  tags                     = var.tags
}

resource "azurerm_storage_container" "deployment" {
  name                  = "flex-deployments"
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"
}

resource "azurerm_service_plan" "this" {
  name                = var.service_plan_name
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = "FC1"
  tags                = var.tags
}

resource "azurerm_function_app_flex_consumption" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  service_plan_id     = azurerm_service_plan.this.id

  storage_container_type      = "blobContainer"
  storage_container_endpoint  = "${azurerm_storage_account.this.primary_blob_endpoint}${azurerm_storage_container.deployment.name}"
  storage_authentication_type = "StorageAccountConnectionString"
  storage_access_key          = azurerm_storage_account.this.primary_access_key

  runtime_name    = "python"
  runtime_version = "3.11"

  maximum_instance_count = 40
  instance_memory_in_mb  = 2048

  site_config {}

  app_settings = merge(
    {
      AzureWebJobsFeatureFlags = "EnableWorkerIndexing"
    },
    var.application_insights_connection_string != "" ? {
      APPLICATIONINSIGHTS_CONNECTION_STRING = var.application_insights_connection_string
    } : {}
  )

  identity {
    type = "SystemAssigned"
  }

  https_only = true
  tags       = var.tags
}
