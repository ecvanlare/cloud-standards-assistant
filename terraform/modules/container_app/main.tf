resource "random_password" "session_pepper" {
  length  = 32
  special = false
}

resource "azurerm_key_vault_secret" "session_pepper" {
  name         = var.session_pepper_secret_name
  value        = random_password.session_pepper.result
  key_vault_id = var.key_vault_id
}

resource "azurerm_role_assignment" "acr_pull" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = var.user_assigned_identity_principal_id
}

resource "azurerm_container_app" "this" {
  name                         = var.name
  container_app_environment_id = var.container_app_environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  workload_profile_name        = "Consumption"
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [var.user_assigned_identity_id]
  }

  registry {
    server   = var.acr_login_server
    identity = var.user_assigned_identity_id
  }

  secret {
    name                = "session-pepper"
    key_vault_secret_id = azurerm_key_vault_secret.session_pepper.versionless_id
    identity            = var.user_assigned_identity_id
  }

  dynamic "secret" {
    for_each = var.application_insights_connection_string != "" ? [1] : []
    content {
      name  = "appinsights-connection-string"
      value = var.application_insights_connection_string
    }
  }

  ingress {
    external_enabled = true
    target_port      = 8000
    transport        = "http"

    traffic_weight {
      percentage      = 100
      latest_revision = true
    }
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = "serving"
      image  = var.image
      cpu    = 0.5
      memory = "1Gi"

      env {
        name  = "FOUNDRY_PROJECT_ENDPOINT"
        value = var.foundry_project_endpoint
      }
      env {
        name  = "AGENT_NAME"
        value = var.agent_name
      }
      env {
        name  = "MANAGED_IDENTITY_CLIENT_ID"
        value = var.user_assigned_identity_client_id
      }
      env {
        name        = "SESSION_PEPPER"
        secret_name = "session-pepper"
      }
      env {
        name  = "MAX_OUTPUT_TOKENS"
        value = "4000"
      }

      dynamic "env" {
        for_each = var.application_insights_connection_string != "" ? [1] : []
        content {
          name        = "APPLICATIONINSIGHTS_CONNECTION_STRING"
          secret_name = "appinsights-connection-string"
        }
      }
    }

    http_scale_rule {
      name                = "http-concurrency"
      concurrent_requests = tostring(var.concurrent_requests)
    }
  }

  depends_on = [
    azurerm_role_assignment.acr_pull,
    azurerm_key_vault_secret.session_pepper,
  ]

  lifecycle {
    ignore_changes = [
      secret,
    ]
  }
}
