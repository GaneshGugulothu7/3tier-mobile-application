# ─── Global ────────────────────────────────────────────────────────────────────
variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "tenant_id" {
  description = "Azure AD tenant ID"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev | test | prod)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be dev, test, or prod."
  }
}

variable "location" {
  description = "Primary Azure region"
  type        = string
  default     = "eastus"
}

variable "project" {
  description = "Short project / workload name used in resource naming"
  type        = string
}

variable "tags" {
  description = "Additional resource tags merged with default tags"
  type        = map(string)
  default     = {}
}

# ─── Networking ────────────────────────────────────────────────────────────────
variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_app_prefix" {
  description = "CIDR for the App Service / Function App integration subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "subnet_db_prefix" {
  description = "CIDR for the database (private endpoint) subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "subnet_apim_prefix" {
  description = "CIDR for the APIM subnet (Developer / Premium SKU)"
  type        = string
  default     = "10.0.3.0/24"
}

# ─── App Service ───────────────────────────────────────────────────────────────
variable "app_service_sku" {
  description = "App Service Plan SKU (e.g. P1v3, P2v3)"
  type        = string
  default     = "P1v3"
}

variable "app_service_min_instances" {
  description = "Minimum autoscale instance count for App Service"
  type        = number
  default     = 1
}

variable "app_service_max_instances" {
  description = "Maximum autoscale instance count for App Service"
  type        = number
  default     = 5
}

# ─── Function App ──────────────────────────────────────────────────────────────
variable "function_app_sku" {
  description = "Consumption (Y1) or Elastic Premium (EP1/EP2/EP3)"
  type        = string
  default     = "EP1"
}

variable "function_runtime" {
  description = "Function App runtime stack"
  type        = string
  default     = "dotnet"
}

variable "function_runtime_version" {
  description = "Runtime version string"
  type        = string
  default     = "~4"
}

# ─── Cosmos DB ─────────────────────────────────────────────────────────────────
variable "cosmos_offer_type" {
  description = "Cosmos DB offer type"
  type        = string
  default     = "Standard"
}

variable "cosmos_consistency_level" {
  description = "Cosmos DB default consistency level"
  type        = string
  default     = "Session"
}

variable "cosmos_databases" {
  description = "Map of Cosmos DB databases and their containers"
  type = map(object({
    throughput = optional(number)
    containers = map(object({
      partition_key_path = string
      throughput         = optional(number)
    }))
  }))
  default = {
    maindb = {
      throughput = null
      containers = {
        items = {
          partition_key_path = "/id"
          throughput         = null
        }
      }
    }
  }
}

# ─── APIM ──────────────────────────────────────────────────────────────────────
variable "apim_sku" {
  description = "APIM SKU (Developer, Premium, etc.)"
  type        = string
  default     = "Developer"
}

variable "apim_publisher_name" {
  description = "APIM publisher display name"
  type        = string
}

variable "apim_publisher_email" {
  description = "APIM publisher email"
  type        = string
}

# ─── Key Vault ─────────────────────────────────────────────────────────────────
variable "kv_soft_delete_retention_days" {
  description = "Key Vault soft-delete retention in days"
  type        = number
  default     = 90
}

# ─── Monitoring ────────────────────────────────────────────────────────────────
variable "log_retention_days" {
  description = "Log Analytics workspace retention in days"
  type        = number
  default     = 30
}
