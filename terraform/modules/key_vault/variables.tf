variable "name" {
  type        = string
  description = "Key Vault name (3-24 chars)."
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "tenant_id" {
  type        = string
  description = "Entra tenant ID for the Key Vault."
}

variable "purge_protection_enabled" {
  type        = bool
  description = "Enable purge protection (recommended for prod)."
  default     = false
}

variable "soft_delete_retention_days" {
  type    = number
  default = 7
}

variable "tags" {
  type    = map(string)
  default = {}
}

