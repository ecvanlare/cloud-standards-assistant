variable "name" {
  type        = string
  description = "User-assigned managed identity name."
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "storage_account_id" {
  type = string
}

variable "key_vault_id" {
  type = string
}

variable "cognitive_account_id" {
  type = string
}

variable "search_service_id" {
  type = string
}

variable "search_principal_id" {
  type        = string
  description = "System-assigned identity of the AI Search service (indexer + embedding skill)."
}

variable "foundry_project_principal_id" {
  type        = string
  description = "System-assigned identity of the Foundry project (Azure AI Search agent tool)."
}

variable "foundry_account_principal_id" {
  type        = string
  description = "System-assigned identity of the Foundry AIServices account (Azure AI Search agent tool)."
}

variable "tags" {
  type    = map(string)
  default = {}
}

