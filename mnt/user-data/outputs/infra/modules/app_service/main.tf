# ─── App Service Plan ─────────────────────────────────────────────────────────
resource "azurerm_service_plan" "this" {
  name                = "asp-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = var.app_service_sku
  tags                = var.tags
}

# ─── App Service ──────────────────────────────────────────────────────────────
resource "azurerm_linux_web_app" "this" {
  name                      = "app-${var.name_prefix}"
  location                  = var.location
  resource_group_name       = var.resource_group_name
  service_plan_id           = azurerm_service_plan.this.id
  virtual_network_subnet_id = var.subnet_id
  https_only                = true
  tags                      = var.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on        = true
    min_tls_version  = "1.2"
    ftps_state       = "Disabled"
    http2_enabled    = true

    application_stack {
      dotnet_version = "8.0"
    }
  }

  app_settings = {
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = var.app_insights_conn_string
    "APPINSIGHTS_INSTRUMENTATIONKEY"        = var.app_insights_key
    "ASPNETCORE_ENVIRONMENT"                = "Production"
    "KeyVaultUri"                           = var.key_vault_uri
    # Reference Cosmos connection from Key Vault
    "CosmosDb__ConnectionString" = "@Microsoft.KeyVault(VaultName=${local.kv_name};SecretName=cosmos-connection-string)"
  }

  logs {
    detailed_error_messages = true
    failed_request_tracing  = true

    http_logs {
      retention_in_days = 7
    }
  }
}

locals {
  kv_name = split("/", var.key_vault_id)[length(split("/", var.key_vault_id)) - 1]
}

# ─── VNet Integration ─────────────────────────────────────────────────────────
# (handled via virtual_network_subnet_id on the web app resource above)

# ─── Autoscale ────────────────────────────────────────────────────────────────
resource "azurerm_monitor_autoscale_setting" "this" {
  name                = "autoscale-${var.name_prefix}-app"
  resource_group_name = var.resource_group_name
  location            = var.location
  target_resource_id  = azurerm_service_plan.this.id
  tags                = var.tags

  profile {
    name = "default"

    capacity {
      default = var.app_service_min_instances
      minimum = var.app_service_min_instances
      maximum = var.app_service_max_instances
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.this.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75
      }
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT5M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.this.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT10M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT10M"
      }
    }
  }
}

# ─── Diagnostic Settings ──────────────────────────────────────────────────────
resource "azurerm_monitor_diagnostic_setting" "app" {
  name                       = "diag-app-${var.name_prefix}"
  target_resource_id         = azurerm_linux_web_app.this.id
  log_analytics_workspace_id = var.log_analytics_id

  enabled_log { category = "AppServiceHTTPLogs" }
  enabled_log { category = "AppServiceConsoleLogs" }
  enabled_log { category = "AppServiceAppLogs" }
  enabled_log { category = "AppServiceAuditLogs" }
  enabled_log { category = "AppServiceIPSecAuditLogs" }
  enabled_log { category = "AppServicePlatformLogs" }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
