variable "name" {
  type        = string
  description = "Virtual network name."
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "address_space" {
  type        = list(string)
  description = "VNet address space."
  default     = ["10.10.0.0/16"]
}

variable "aca_subnet_name" {
  type        = string
  description = "Subnet name for Container Apps."
}

variable "aca_subnet_prefix" {
  type        = string
  description = "CIDR for the Container Apps subnet (must be /23 or larger for ACA VNet integration)."
  default     = "10.10.0.0/23"
}

variable "tags" {
  type    = map(string)
  default = {}
}

