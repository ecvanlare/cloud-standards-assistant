variable "name" {
  type        = string
  description = "AI Search service name."
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "sku" {
  type        = string
  description = "Search SKU (e.g. basic, standard)."
  default     = "basic"
}

variable "replica_count" {
  type    = number
  default = 1
}

variable "partition_count" {
  type    = number
  default = 1
}

variable "tags" {
  type    = map(string)
  default = {}
}

