resource "azurerm_cognitive_account" "this" {
  name                          = var.name
  location                      = var.location
  resource_group_name           = var.resource_group_name
  kind                          = "AIServices"
  sku_name                      = var.sku_name
  custom_subdomain_name         = var.custom_subdomain_name
  project_management_enabled    = true
  public_network_access_enabled = true
  local_auth_enabled            = false

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

resource "azurerm_cognitive_account_project" "this" {
  name                 = var.project_name
  cognitive_account_id = azurerm_cognitive_account.this.id
  location             = var.location
  display_name         = var.project_name
  description          = "Cloud Standards Assistant Foundry project"

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# azapi rather than azurerm_cognitive_account_rai_policy: azurerm requires severity_threshold on
# Jailbreak / Protected Material, which the API stores as null, so plans would never converge.
resource "azapi_resource" "rai_policy" {
  type                      = "Microsoft.CognitiveServices/accounts/raiPolicies@2025-06-01"
  name                      = var.rai_policy_name
  parent_id                 = azurerm_cognitive_account.this.id
  schema_validation_enabled = false

  body = {
    properties = {
      mode           = "Blocking"
      basePolicyName = "Microsoft.DefaultV2"
      contentFilters = concat(
        flatten([
          for category in ["Hate", "Sexual", "Violence", "Selfharm"] : [
            for source in ["Prompt", "Completion"] : {
              name              = category
              enabled           = true
              blocking          = true
              severityThreshold = "Medium"
              source            = source
            }
          ]
        ]),
        [
          { name = "Jailbreak", enabled = true, blocking = true, source = "Prompt" },
          { name = "Protected Material Text", enabled = true, blocking = true, source = "Completion" },
        ]
      )
    }
  }
}

resource "azapi_resource" "search_connection" {
  type                      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01"
  name                      = var.search_connection_name
  parent_id                 = azurerm_cognitive_account_project.this.id
  schema_validation_enabled = false

  body = {
    properties = {
      category      = "CognitiveSearch"
      target        = var.search_endpoint
      authType      = "AAD"
      isSharedToAll = true
      metadata = {
        ApiType    = "Azure"
        ResourceId = var.search_service_id
        location   = var.location
      }
    }
  }
}

resource "azapi_resource" "storage_connection" {
  type                      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01"
  name                      = var.storage_connection_name
  parent_id                 = azurerm_cognitive_account_project.this.id
  schema_validation_enabled = false

  body = {
    properties = {
      category      = "AzureStorageAccount"
      target        = var.storage_blob_endpoint
      authType      = "AAD"
      isSharedToAll = true
      metadata = {
        ApiType    = "Azure"
        ResourceId = var.storage_account_id
        location   = var.location
      }
    }
  }
}

resource "azapi_resource" "appinsights_connection" {
  type                      = "Microsoft.CognitiveServices/accounts/projects/connections@2025-06-01"
  name                      = var.appinsights_connection_name
  parent_id                 = azurerm_cognitive_account_project.this.id
  schema_validation_enabled = false

  body = {
    properties = {
      category      = "AppInsights"
      target        = var.application_insights_id
      authType      = "ApiKey"
      isSharedToAll = true
      metadata = {
        ApiType    = "Azure"
        ResourceId = var.application_insights_id
      }
    }
  }

  sensitive_body = {
    properties = {
      credentials = {
        key = var.application_insights_connection_string
      }
    }
  }
}

resource "azurerm_cognitive_deployment" "chat" {
  name                 = var.chat_deployment_name
  cognitive_account_id = azurerm_cognitive_account.this.id
  rai_policy_name      = azapi_resource.rai_policy.name

  model {
    format  = "OpenAI"
    name    = var.chat_model_name
    version = var.chat_model_version
  }

  sku {
    name     = "GlobalStandard"
    capacity = var.chat_capacity
  }

  depends_on = [azurerm_cognitive_account_project.this]
}

resource "azurerm_cognitive_deployment" "embedding" {
  name                 = var.embedding_deployment_name
  cognitive_account_id = azurerm_cognitive_account.this.id

  model {
    format  = "OpenAI"
    name    = var.embedding_model_name
    version = var.embedding_model_version
  }

  sku {
    name     = "GlobalStandard"
    capacity = var.embedding_capacity
  }

  depends_on = [azurerm_cognitive_deployment.chat]
}

resource "azurerm_cognitive_deployment" "agent" {
  name                 = var.agent_deployment_name
  cognitive_account_id = azurerm_cognitive_account.this.id
  rai_policy_name      = azapi_resource.rai_policy.name

  model {
    format  = "OpenAI"
    name    = var.agent_model_name
    version = var.agent_model_version
  }

  sku {
    name     = "GlobalStandard"
    capacity = var.agent_capacity
  }

  depends_on = [azurerm_cognitive_deployment.embedding]
}

