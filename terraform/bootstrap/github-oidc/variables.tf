variable "subscription_id" {
  type        = string
  description = "Azure subscription ID. Set in terraform.tfvars (see terraform.tfvars.example)."
}

variable "github_repository" {
  type        = string
  description = "GitHub repository as owner/name; used in the federated credential subjects."
}

variable "environments" {
  type        = list(string)
  description = "GitHub Environments that get their own deploy identity."
  default     = ["dev", "staging", "prod"]
}

variable "location" {
  type    = string
  default = "uksouth"
}

variable "resource_group_name" {
  type        = string
  description = "Holds the deploy identities; separate from env groups so teardown never removes them."
  default     = "rg-csa-github-uks"
}

variable "state_resource_group_name" {
  type    = string
  default = "rg-csa-tfstate-uks"
}

variable "state_storage_account_name" {
  type    = string
  default = "stcsatfstateuks"
}

variable "assignable_roles" {
  type        = list(string)
  description = "Roles the env Terraform assigns; the deploy identity may grant only these."
  default = [
    "AcrPull",
    "AcrPush",
    "Cognitive Services User",
    "Foundry User",
    "Key Vault Secrets Officer",
    "Key Vault Secrets User",
    "Search Index Data Contributor",
    "Search Service Contributor",
    "Storage Blob Data Contributor",
    "Storage Blob Data Reader",
  ]
}
