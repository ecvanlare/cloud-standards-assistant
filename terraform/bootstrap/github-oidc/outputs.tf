output "client_ids" {
  description = "AZURE_CLIENT_ID per GitHub Environment."
  value       = { for env, identity in azurerm_user_assigned_identity.deploy : env => identity.client_id }
}

output "principal_ids" {
  description = "Object IDs to add to operator_object_ids in each env's terraform.tfvars."
  value       = { for env, identity in azurerm_user_assigned_identity.deploy : env => identity.principal_id }
}

output "tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}
