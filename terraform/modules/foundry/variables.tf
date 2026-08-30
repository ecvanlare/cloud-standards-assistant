variable "name" {
  type        = string
  description = "AI Services / Foundry account name."
}

variable "project_name" {
  type        = string
  description = "Foundry project name."
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "sku_name" {
  type        = string
  description = "AI Services SKU."
  default     = "S0"
}

variable "custom_subdomain_name" {
  type        = string
  description = "Custom subdomain for the AI Services account (required for Foundry projects)."
}

variable "chat_model_name" {
  type        = string
  description = "Catalog model name for chat."
  default     = "gpt-5-mini"
}

variable "chat_model_version" {
  type    = string
  default = "2025-08-07"
}

variable "chat_deployment_name" {
  type    = string
  default = "gpt-5-mini"
}

variable "chat_capacity" {
  type        = number
  description = "Throughput units (thousands of tokens per minute) for chat."
  default     = 10
}

variable "embedding_model_name" {
  type    = string
  default = "text-embedding-3-small"
}

variable "embedding_model_version" {
  type    = string
  default = "1"
}

variable "embedding_deployment_name" {
  type    = string
  default = "text-embedding-3-small"
}

variable "embedding_capacity" {
  type    = number
  default = 10
}

variable "tags" {
  type    = map(string)
  default = {}
}

