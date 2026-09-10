variable "subscription_id" {
  type        = string
  description = "Azure subscription ID. Set in terraform.tfvars (see terraform.tfvars.example)."
}

variable "environment" {
  type        = string
  description = "Environment name (dev, staging, prod)."
}

variable "location" {
  type        = string
  description = "Azure region."
  default     = "uksouth"
}

variable "search_sku" {
  type        = string
  description = "Azure AI Search SKU."
  default     = "basic"
}

variable "key_vault_purge_protection_enabled" {
  type    = bool
  default = false
}

variable "chat_capacity" {
  type        = number
  description = "Chat model deployment capacity (TPM in thousands)."
  default     = 10
}

variable "embedding_capacity" {
  type        = number
  description = "Embedding model deployment capacity (TPM in thousands)."
  default     = 10
}

variable "serving_image_tag" {
  type        = string
  description = "ACR tag for the serving Container App image (pushed by serving/scripts/deploy-serving.sh)."
  default     = "latest"
}

variable "serving_min_replicas" {
  type    = number
  default = 0
}

variable "serving_max_replicas" {
  type    = number
  default = 5
}

variable "serving_concurrent_requests" {
  type        = number
  description = "HTTP concurrent requests per replica before scale-out."
  default     = 10
}
