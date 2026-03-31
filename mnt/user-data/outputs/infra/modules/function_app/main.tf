resource "azurerm_storage_account" "fn" {
  name                     = "st${replace(var.name_prefix, "-", "")}fn"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  https_traffic_only_enabled = true

  # Restrict access to the app subnet
  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    virtual_network_subnet_ids = [var.subnet_id]
  }

  tags = var.tags
}

# ─── Elastic Premium / Consumption Service Plan ───────────────────────────────
resource "azurerm_service_plan" "fn" {
  name                = "asp-${var.name_prefix}-fn"
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = var.function_app_sku   # EP1, EP2, EP3, or Y1
  tags                = var.tags
}

# ─── Function App ─────────────────────────────────────────────────────────────
resource "azurerm_linux_function_app" "this" {
  name                       = "func-${var.name_prefix}"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  service_plan_id            = azurerm_service_plan.fn.id
  storage_account_name       = azurerm_storage_account.fn.name
  storage_account_access_key = azurerm_storage_account.fn.primary_access_key
  virtual_network_subnet_id  = var.subnet_id
  https_only                 = true
  tags                       = var.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on        = var.function_app_sku != "Y1"   # always_on not valid for Consumption
    min_tls_version  = "1.2"
    ftps_state       = "Disabled"
    http2_enabled    = true
    elastic_instance_minimum = var.function_app_sku != "Y1" ? 1 : null

    application_stack {
      use_dotnet_isolated_runtime = true
      dotnet_version              = "8.0"
    }
  }

  app_settings = {
    "APPLICATIONINSIGHTS_CONNECTION_STRING"  = var.app_insights_conn_string
    "APPINSIGHTS_INSTRUMENTATIONKEY"         = var.app_insights_key
    "FUNCTIONS_WORKER_RUNTIME"               = var.function_runtime
    "FUNCTIONS_EXTENSION_VERSION"            = var.function_runtime_version
    "KeyVaultUri"                            = var.key_vault_uri
    "CosmosDb__ConnectionString"             = "@Microsoft.KeyVault(VaultName=${local.kv_name};SecretName=cosmos-connection-string)"
    "WEBSITE_RUN_FROM_PACKAGE"               = "1"
  }
}

locals {
  kv_name = split("/", var.key_vault_id)[length(split("/", var.key_vault_id)) - 1]
}

# ─── Autoscale (only meaningful for Elastic Premium) ──────────────────────────
resource "azurerm_monitor_autoscale_setting" "fn" {
  count               = var.function_app_sku != "Y1" ? 1 : 0
  name                = "autoscale-${var.name_prefix}-fn"
  resource_group_name = var.resource_group_name
  location            = var.location
  target_resource_id  = azurerm_service_plan.fn.id
  tags                = var.tags

  profile {
    name = "default"

    capacity {
      default = 1
      minimum = 1
      maximum = 10
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.fn.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
      }
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "2"
        cooldown  = "PT3M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.fn.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT10M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 20
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
resource "azurerm_monitor_diagnostic_setting" "fn" {
  name                       = "diag-fn-${var.name_prefix}"
  target_resource_id         = azurerm_linux_function_app.this.id
  log_analytics_workspace_id = var.log_analytics_id

  enabled_log { category = "FunctionAppLogs" }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
