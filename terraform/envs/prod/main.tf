data "azurerm_client_config" "current" {}

module "resource_group" {
  source = "../../modules/resource_group"

  name     = local.names.rg
  location = local.location
  tags     = local.tags
}

module "network" {
  source = "../../modules/network"

  name                = local.names.vnet
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
  aca_subnet_name     = local.names.snet_aca
  tags                = local.tags
}

module "storage" {
  source = "../../modules/storage"

  name                = local.storage_name
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
  tags                = local.tags
}

module "key_vault" {
  source = "../../modules/key_vault"

  name                     = local.key_vault_name
  location                 = module.resource_group.location
  resource_group_name      = module.resource_group.name
  tenant_id                = data.azurerm_client_config.current.tenant_id
  purge_protection_enabled = var.key_vault_purge_protection_enabled
  tags                     = local.tags
}

module "ai_search" {
  source = "../../modules/ai_search"

  name                = local.names.search
  location            = module.resource_group.location
  resource_group_name = module.resource_group.name
  sku                 = var.search_sku
  tags                = local.tags
}

module "foundry" {
  source = "../../modules/foundry"

  name                  = local.names.ais
  project_name          = local.names.project
  location              = module.resource_group.location
  resource_group_name   = module.resource_group.name
  custom_subdomain_name = local.names.ais
  chat_capacity         = var.chat_capacity
  embedding_capacity    = var.embedding_capacity
  tags                  = local.tags
}

module "container_apps_env" {
  source = "../../modules/container_apps_env"

  name                     = local.names.cae
  log_analytics_name       = local.names.log
  location                 = module.resource_group.location
  resource_group_name      = module.resource_group.name
  infrastructure_subnet_id = module.network.aca_subnet_id
  tags                     = local.tags
}

module "identity" {
  source = "../../modules/identity"

  name                         = local.names.id
  location                     = module.resource_group.location
  resource_group_name          = module.resource_group.name
  storage_account_id           = module.storage.id
  key_vault_id                 = module.key_vault.id
  cognitive_account_id         = module.foundry.account_id
  search_service_id            = module.ai_search.id
  search_principal_id          = module.ai_search.principal_id
  foundry_project_principal_id = module.foundry.project_principal_id
  foundry_account_principal_id = module.foundry.account_principal_id
  tags                         = local.tags
}

module "function_app" {
  for_each = local.function_apps
  source   = "../../modules/function_app"

  name                 = "func-${each.key}-${local.workload}-${local.env}-${random_string.suffix.result}"
  location             = module.resource_group.location
  resource_group_name  = module.resource_group.name
  storage_account_name = "stf${each.key}${local.workload}${local.env}${random_string.suffix.result}"
  service_plan_name    = "asp-${local.workload}-${local.env}-${each.key}"
  tags                 = local.tags
}
