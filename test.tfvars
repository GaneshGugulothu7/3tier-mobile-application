# test.tfvars
environment     = "test"
project         = "myapp"
location        = "eastus"

app_service_sku           = "P1v3"
app_service_min_instances = 1
app_service_max_instances = 5

function_app_sku = "EP1"

apim_sku            = "Developer"
apim_publisher_name = "My Company"

log_retention_days            = 30
kv_soft_delete_retention_days = 30

tags = {
  environment = "test"
  owner       = "platform-team"
}
