variable "name" {
  type        = string
  description = "Application Insights component name."
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "log_analytics_workspace_id" {
  type        = string
  description = "Existing Log Analytics workspace id (workspace-based Application Insights)."
}

variable "tags" {
  type    = map(string)
  default = {}
}
