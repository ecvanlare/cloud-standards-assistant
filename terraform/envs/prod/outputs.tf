output "resource_group_name" {
  value = module.resource_group.name
}

output "location" {
  value = module.resource_group.location
}

output "vnet_id" {
  value = module.network.vnet_id
}

output "aca_subnet_id" {
  value = module.network.aca_subnet_id
}

output "storage_account_name" {
  value = module.storage.name
}

output "storage_blob_endpoint" {
  value = module.storage.primary_blob_endpoint
}

output "corpus_container_name" {
  value = module.storage.corpus_container_name
}

output "key_vault_uri" {
  value = module.key_vault.uri
}

output "search_endpoint" {
  value = module.ai_search.endpoint
}

output "foundry_endpoint" {
  value = module.foundry.endpoint
}

output "foundry_account_name" {
  value = module.foundry.account_name
}

output "foundry_project_id" {
  value = module.foundry.project_id
}

output "foundry_project_name" {
  value = module.foundry.project_name
}

output "foundry_project_endpoint" {
  value = module.foundry.project_endpoint
}

output "chat_deployment_name" {
  value = module.foundry.chat_deployment_name
}

output "embedding_deployment_name" {
  value = module.foundry.embedding_deployment_name
}

output "container_apps_environment_id" {
  value = module.container_apps_env.id
}

output "managed_identity_client_id" {
  value = module.identity.client_id
}

output "managed_identity_principal_id" {
  value = module.identity.principal_id
}

output "function_app_name" {
  value = module.function_app["asb"].name
}

output "function_base_url" {
  value = module.function_app["asb"].function_base_url
}

output "registry_function_app_name" {
  value = module.function_app["reg"].name
}

output "registry_function_base_url" {
  value = module.function_app["reg"].function_base_url
}

output "function_apps" {
  value = {
    for key, app in module.function_app : key => {
      name     = app.name
      base_url = app.function_base_url
    }
  }
}

output "application_insights_name" {
  value = module.monitoring.name
}

output "application_insights_connection_string" {
  value     = module.monitoring.connection_string
  sensitive = true
}

output "application_insights_app_id" {
  value = module.monitoring.app_id
}
