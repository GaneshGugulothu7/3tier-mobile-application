# prod.tfvars
environment     = "prod"
project         = "myapp"
location        = "eastus"

app_service_sku           = "P2v3"
app_service_min_instances = 2
app_service_max_instances = 10

function_app_sku = "EP2"

apim_sku            = "Premium"
apim_publisher_name = "My Company"

log_retention_days            = 90
kv_soft_delete_retention_days = 90

tags = {
  environment = "prod"
  owner       = "platform-team"
  criticality = "high"
}
