data "azurerm_client_config" "current" {}

resource "random_string" "kv_suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "azurerm_key_vault" "this" {
  # Key Vault names: 3-24 chars, globally unique
  name                = "kv-${var.name_prefix}-${random_string.kv_suffix.result}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = "standard"

  soft_delete_retention_days  = var.kv_soft_delete_retention_days
  purge_protection_enabled    = true
  enable_rbac_authorization   = true   # RBAC mode – no access policies

  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = [var.subnet_id]
    ip_rules                   = []
  }

  tags = var.tags
}

# ─── Give the Terraform service principal Key Vault Administrator role ─────────
# so it can create/update secrets during apply
resource "azurerm_role_assignment" "tf_kv_admin" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# ─── Diagnostic Settings ──────────────────────────────────────────────────────
resource "azurerm_monitor_diagnostic_setting" "kv" {
  name                       = "diag-kv-${var.name_prefix}"
  target_resource_id         = azurerm_key_vault.this.id
  log_analytics_workspace_id = var.log_analytics_id

  enabled_log { category = "AuditEvent" }
  enabled_log { category = "AzurePolicyEvaluationDetails" }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
