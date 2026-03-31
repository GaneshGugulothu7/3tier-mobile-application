locals {
  name_prefix = "${var.environment}-${var.project}"

  default_tags = {
    environment = var.environment
    project     = var.project
    managed_by  = "terraform"
  }

  tags = merge(local.default_tags, var.tags)
}

# ─── Resource Group ────────────────────────────────────────────────────────────
module "resource_group" {
  source = "./modules/resource_group"

  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = local.tags
}

# ─── Monitoring (deploy early – other modules reference workspace ID) ──────────
module "monitoring" {
  source = "./modules/monitoring"

  name_prefix         = local.name_prefix
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  log_retention_days  = var.log_retention_days
  tags                = local.tags
}

# ─── Networking ────────────────────────────────────────────────────────────────
module "network" {
  source = "./modules/network"

  name_prefix         = local.name_prefix
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  vnet_address_space  = var.vnet_address_space
  subnet_app_prefix   = var.subnet_app_prefix
  subnet_db_prefix    = var.subnet_db_prefix
  subnet_apim_prefix  = var.subnet_apim_prefix
  log_analytics_id    = module.monitoring.log_analytics_workspace_id
  tags                = local.tags
}

# ─── Key Vault ─────────────────────────────────────────────────────────────────
module "key_vault" {
  source = "./modules/key_vault"

  name_prefix                   = local.name_prefix
  resource_group_name           = module.resource_group.name
  location                      = module.resource_group.location
  tenant_id                     = var.tenant_id
  kv_soft_delete_retention_days = var.kv_soft_delete_retention_days
  subnet_id                     = module.network.subnet_app_id
  log_analytics_id              = module.monitoring.log_analytics_workspace_id
  tags                          = local.tags
}

# ─── App Service ───────────────────────────────────────────────────────────────
module "app_service" {
  source = "./modules/app_service"

  name_prefix               = local.name_prefix
  resource_group_name       = module.resource_group.name
  location                  = module.resource_group.location
  app_service_sku           = var.app_service_sku
  app_service_min_instances = var.app_service_min_instances
  app_service_max_instances = var.app_service_max_instances
  subnet_id                 = module.network.subnet_app_id
  key_vault_id              = module.key_vault.key_vault_id
  key_vault_uri             = module.key_vault.key_vault_uri
  app_insights_conn_string  = module.monitoring.app_insights_connection_string
  app_insights_key          = module.monitoring.app_insights_instrumentation_key
  log_analytics_id          = module.monitoring.log_analytics_workspace_id
  tags                      = local.tags
}

# ─── Function App ──────────────────────────────────────────────────────────────
module "function_app" {
  source = "./modules/function_app"

  name_prefix              = local.name_prefix
  resource_group_name      = module.resource_group.name
  location                 = module.resource_group.location
  function_app_sku         = var.function_app_sku
  function_runtime         = var.function_runtime
  function_runtime_version = var.function_runtime_version
  subnet_id                = module.network.subnet_app_id
  key_vault_id             = module.key_vault.key_vault_id
  key_vault_uri            = module.key_vault.key_vault_uri
  app_insights_conn_string = module.monitoring.app_insights_connection_string
  app_insights_key         = module.monitoring.app_insights_instrumentation_key
  log_analytics_id         = module.monitoring.log_analytics_workspace_id
  tags                     = local.tags
}

# ─── Cosmos DB ─────────────────────────────────────────────────────────────────
module "cosmosdb" {
  source = "./modules/cosmosdb"

  name_prefix              = local.name_prefix
  resource_group_name      = module.resource_group.name
  location                 = module.resource_group.location
  cosmos_offer_type        = var.cosmos_offer_type
  cosmos_consistency_level = var.cosmos_consistency_level
  cosmos_databases         = var.cosmos_databases
  subnet_db_id             = module.network.subnet_db_id
  vnet_id                  = module.network.vnet_id
  log_analytics_id         = module.monitoring.log_analytics_workspace_id
  key_vault_id             = module.key_vault.key_vault_id
  tags                     = local.tags
}

# ─── API Management ────────────────────────────────────────────────────────────
module "api_management" {
  source = "./modules/api_management"

  name_prefix          = local.name_prefix
  resource_group_name  = module.resource_group.name
  location             = module.resource_group.location
  apim_sku             = var.apim_sku
  publisher_name       = var.apim_publisher_name
  publisher_email      = var.apim_publisher_email
  subnet_id            = module.network.subnet_apim_id
  app_insights_id      = module.monitoring.app_insights_id
  app_insights_key     = module.monitoring.app_insights_instrumentation_key
  log_analytics_id     = module.monitoring.log_analytics_workspace_id
  backend_app_hostname = module.app_service.default_hostname
  tags                 = local.tags
}

# ─── RBAC: App Service → Key Vault ─────────────────────────────────────────────
resource "azurerm_role_assignment" "app_service_kv" {
  scope                = module.key_vault.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.app_service.principal_id
}

# ─── RBAC: Function App → Key Vault ───────────────────────────────────────────
resource "azurerm_role_assignment" "function_app_kv" {
  scope                = module.key_vault.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.function_app.principal_id
}

# ─── RBAC: APIM → Key Vault ───────────────────────────────────────────────────
resource "azurerm_role_assignment" "apim_kv" {
  scope                = module.key_vault.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.api_management.principal_id
}

# ─── Store Cosmos DB connection string in Key Vault ───────────────────────────
resource "azurerm_key_vault_secret" "cosmos_connection" {
  name         = "cosmos-connection-string"
  value        = module.cosmosdb.primary_connection_string
  key_vault_id = module.key_vault.key_vault_id

  depends_on = [module.key_vault, module.cosmosdb]
}
