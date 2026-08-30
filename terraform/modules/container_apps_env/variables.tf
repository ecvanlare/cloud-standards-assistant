variable "name" {
  type        = string
  description = "Container Apps environment name."
}

variable "log_analytics_name" {
  type        = string
  description = "Log Analytics workspace name."
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "infrastructure_subnet_id" {
  type        = string
  description = "Delegated subnet for ACA environment."
}

variable "tags" {
  type    = map(string)
  default = {}
}

