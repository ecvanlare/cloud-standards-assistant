data "azurerm_client_config" "current" {}

data "azurerm_subscription" "current" {}

data "azurerm_storage_account" "state" {
  name                = var.state_storage_account_name
  resource_group_name = var.state_resource_group_name
}

data "azurerm_role_definition" "assignable" {
  for_each = toset(var.assignable_roles)

  name  = each.value
  scope = data.azurerm_subscription.current.id
}

locals {
  github_issuer = "https://token.actions.githubusercontent.com"
  role_guids    = join(", ", [for role in data.azurerm_role_definition.assignable : basename(role.role_definition_id)])

  # Role Based Access Control Administrator may create or delete only the roles listed above.
  rbac_condition = <<-EOT
    (
     (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})
     )
     OR
     (
      @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.role_guids}}
     )
    )
    AND
    (
     (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})
     )
     OR
     (
      @Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.role_guids}}
     )
    )
  EOT
}

resource "azurerm_resource_group" "github" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    workload   = "csa"
    managed_by = "terraform"
    project    = "cloud-standards-assistant"
    purpose    = "github-deploy-identity"
  }
}

resource "azurerm_user_assigned_identity" "deploy" {
  for_each = toset(var.environments)

  name                = "id-csa-github-${each.value}"
  location            = azurerm_resource_group.github.location
  resource_group_name = azurerm_resource_group.github.name
  tags                = azurerm_resource_group.github.tags
}

resource "azurerm_federated_identity_credential" "github" {
  for_each = azurerm_user_assigned_identity.deploy

  name      = "github-environment-${each.key}"
  parent_id = each.value.id
  audience  = ["api://AzureADTokenExchange"]
  issuer    = local.github_issuer
  subject   = "${var.github_subject_prefix}:environment:${each.key}"
}

resource "azurerm_role_assignment" "contributor" {
  for_each = azurerm_user_assigned_identity.deploy

  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Contributor"
  principal_id         = each.value.principal_id
}

resource "azurerm_role_assignment" "rbac_admin" {
  for_each = azurerm_user_assigned_identity.deploy

  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Role Based Access Control Administrator"
  principal_id         = each.value.principal_id
  condition            = local.rbac_condition
  condition_version    = "2.0"
}

resource "azurerm_role_assignment" "state_blob" {
  for_each = azurerm_user_assigned_identity.deploy

  scope                = data.azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = each.value.principal_id
}