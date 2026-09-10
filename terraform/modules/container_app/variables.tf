variable "name" {
  type        = string
  description = "Container App name."
}

variable "resource_group_name" {
  type = string
}

variable "container_app_environment_id" {
  type = string
}

variable "user_assigned_identity_id" {
  type = string
}

variable "user_assigned_identity_client_id" {
  type = string
}

variable "user_assigned_identity_principal_id" {
  type = string
}

variable "acr_login_server" {
  type = string
}

variable "acr_id" {
  type = string
}

variable "image" {
  type        = string
  description = "Full image reference (login_server/repo:tag)."
}

variable "foundry_project_endpoint" {
  type = string
}

variable "agent_name" {
  type    = string
  default = "cloud-devops-standards-assistant"
}

variable "key_vault_id" {
  type = string
}

variable "session_pepper_secret_name" {
  type    = string
  default = "serving-session-pepper"
}

variable "min_replicas" {
  type    = number
  default = 0
}

variable "max_replicas" {
  type    = number
  default = 5
}

variable "concurrent_requests" {
  type        = number
  description = "HTTP concurrent request threshold to scale out."
  default     = 10
}

variable "application_insights_connection_string" {
  type        = string
  description = "App Insights connection string for BFF OpenTelemetry (same workspace as Foundry/Functions)."
  default     = ""
  sensitive   = true
}

variable "tags" {
  type    = map(string)
  default = {}
}
