variable "name" {
  type        = string
  description = "Function App name."
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "storage_account_name" {
  type        = string
  description = "Dedicated storage account for the Function App (AzureWebJobsStorage)."
}

variable "service_plan_name" {
  type        = string
  description = "Flex Consumption (FC1) App Service plan name."
}

variable "tags" {
  type    = map(string)
  default = {}
}
