variable "name" {
  type        = string
  description = "Storage account name (3-24 lowercase alphanumeric)."
}

variable "location" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "corpus_container_name" {
  type        = string
  description = "Blob container for corpus documents."
  default     = "corpus"
}

