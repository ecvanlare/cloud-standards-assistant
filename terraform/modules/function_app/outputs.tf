output "id" {
  value = azurerm_function_app_flex_consumption.this.id
}

output "name" {
  value = azurerm_function_app_flex_consumption.this.name
}

output "default_hostname" {
  value = azurerm_function_app_flex_consumption.this.default_hostname
}

output "function_base_url" {
  value = "https://${azurerm_function_app_flex_consumption.this.default_hostname}/api"
}

output "principal_id" {
  value = azurerm_function_app_flex_consumption.this.identity[0].principal_id
}

output "storage_account_name" {
  value = azurerm_storage_account.this.name
}

output "service_plan_name" {
  value = azurerm_service_plan.this.name
}
