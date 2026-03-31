# ─── Resource Group ────────────────────────────────────────────────────────────
output "resource_group_name" {
  description = "Name of the primary resource group"
  value       = module.resource_group.name
}

# ─── Networking ────────────────────────────────────────────────────────────────
output "vnet_id" {
  description = "Virtual Network resource ID"
  value       = module.network.vnet_id
}

output "subnet_app_id" {
  description = "App subnet resource ID"
  value       = module.network.subnet_app_id
}

output "subnet_db_id" {
  description = "Database subnet resource ID"
  value       = module.network.subnet_db_id
}

# ─── App Service ───────────────────────────────────────────────────────────────
output "app_service_default_hostname" {
  description = "Default hostname of the App Service"
  value       = module.app_service.default_hostname
}

output "app_service_principal_id" {
  description = "Managed Identity principal ID for App Service"
  value       = module.app_service.principal_id
}

# ─── Function App ──────────────────────────────────────────────────────────────
output "function_app_default_hostname" {
  description = "Default hostname of the Function App"
  value       = module.function_app.default_hostname
}

output "function_app_principal_id" {
  description = "Managed Identity principal ID for Function App"
  value       = module.function_app.principal_id
}

# ─── API Management ────────────────────────────────────────────────────────────
output "apim_gateway_url" {
  description = "APIM gateway URL"
  value       = module.api_management.gateway_url
}

output "apim_portal_url" {
  description = "APIM developer portal URL"
  value       = module.api_management.portal_url
}

# ─── Cosmos DB ─────────────────────────────────────────────────────────────────
output "cosmos_account_endpoint" {
  description = "Cosmos DB account endpoint"
  value       = module.cosmosdb.endpoint
}

# ─── Key Vault ─────────────────────────────────────────────────────────────────
output "key_vault_uri" {
  description = "Key Vault URI"
  value       = module.key_vault.key_vault_uri
}

output "key_vault_id" {
  description = "Key Vault resource ID"
  value       = module.key_vault.key_vault_id
}

# ─── Monitoring ────────────────────────────────────────────────────────────────
output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace resource ID"
  value       = module.monitoring.log_analytics_workspace_id
}

output "app_insights_instrumentation_key" {
  description = "Application Insights instrumentation key"
  value       = module.monitoring.app_insights_instrumentation_key
  sensitive   = true
}

output "app_insights_connection_string" {
  description = "Application Insights connection string"
  value       = module.monitoring.app_insights_connection_string
  sensitive   = true
}
