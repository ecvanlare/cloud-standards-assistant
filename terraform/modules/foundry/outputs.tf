output "account_id" {
  value = azurerm_cognitive_account.this.id
}

output "account_name" {
  value = azurerm_cognitive_account.this.name
}

output "endpoint" {
  value = azurerm_cognitive_account.this.endpoint
}

output "project_id" {
  value = azurerm_cognitive_account_project.this.id
}

output "project_name" {
  value = azurerm_cognitive_account_project.this.name
}

output "account_principal_id" {
  value = azurerm_cognitive_account.this.identity[0].principal_id
}

output "project_principal_id" {
  value = azurerm_cognitive_account_project.this.identity[0].principal_id
}

output "chat_deployment_name" {
  value = azurerm_cognitive_deployment.chat.name
}

output "embedding_deployment_name" {
  value = azurerm_cognitive_deployment.embedding.name
}

