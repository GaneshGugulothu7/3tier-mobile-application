resource "azurerm_cosmosdb_account" "this" {
  name                = "cosmos-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  offer_type          = var.cosmos_offer_type
  kind                = "GlobalDocumentDB"

  automatic_failover_enabled      = false
  public_network_access_enabled   = false   # private endpoint only
  local_authentication_disabled   = true    # force RBAC / AAD auth

  consistency_policy {
    consistency_level = var.cosmos_consistency_level
  }

  geo_location {
    location          = var.location
    failover_priority = 0
  }

  # IP firewall – deny all public IPs; private endpoint handles access
  ip_range_filter = ""

  tags = var.tags
}

# ─── Databases & Containers ───────────────────────────────────────────────────
resource "azurerm_cosmosdb_sql_database" "db" {
  for_each = var.cosmos_databases

  name                = each.key
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.this.name
  throughput          = each.value.throughput
}

resource "azurerm_cosmosdb_sql_container" "container" {
  for_each = {
    for pair in flatten([
      for db_key, db in var.cosmos_databases : [
        for c_key, c in db.containers : {
          key                = "${db_key}__${c_key}"
          db_key             = db_key
          container_key      = c_key
          partition_key_path = c.partition_key_path
          throughput         = c.throughput
        }
      ]
    ]) : pair.key => pair
  }

  name                = each.value.container_key
  resource_group_name = var.resource_group_name
  account_name        = azurerm_cosmosdb_account.this.name
  database_name       = each.value.db_key
  partition_key_path  = each.value.partition_key_path
  throughput          = each.value.throughput

  depends_on = [azurerm_cosmosdb_sql_database.db]
}

# ─── Private DNS Zone ─────────────────────────────────────────────────────────
resource "azurerm_private_dns_zone" "cosmos" {
  name                = "privatelink.documents.azure.com"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "cosmos" {
  name                  = "pdns-link-cosmos-${var.name_prefix}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.cosmos.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

# ─── Private Endpoint ─────────────────────────────────────────────────────────
resource "azurerm_private_endpoint" "cosmos" {
  name                = "pe-cosmos-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_db_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-cosmos-${var.name_prefix}"
    private_connection_resource_id = azurerm_cosmosdb_account.this.id
    subresource_names              = ["Sql"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "cosmos-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.cosmos.id]
  }
}

# ─── Store primary key in Key Vault ───────────────────────────────────────────
resource "azurerm_key_vault_secret" "cosmos_key" {
  name         = "cosmos-primary-key"
  value        = azurerm_cosmosdb_account.this.primary_key
  key_vault_id = var.key_vault_id
}

# ─── Diagnostic Settings ──────────────────────────────────────────────────────
resource "azurerm_monitor_diagnostic_setting" "cosmos" {
  name                       = "diag-cosmos-${var.name_prefix}"
  target_resource_id         = azurerm_cosmosdb_account.this.id
  log_analytics_workspace_id = var.log_analytics_id

  enabled_log { category = "DataPlaneRequests" }
  enabled_log { category = "QueryRuntimeStatistics" }
  enabled_log { category = "PartitionKeyStatistics" }
  enabled_log { category = "ControlPlaneRequests" }

  metric {
    category = "Requests"
    enabled  = true
  }
}
