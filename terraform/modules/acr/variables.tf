variable "name" {
  type        = string
  description = "Azure Container Registry name (alphanumeric, globally unique)."
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "sku" {
  type    = string
  default = "Basic"
}

variable "tags" {
  type    = map(string)
  default = {}
}
