# Azure Infrastructure – Terraform + Azure DevOps

## Architecture Overview

```
Internet → APIM (Internal VNet) → App Service (VNet integrated) → Cosmos DB (Private Endpoint)
                                ↘ Function App (VNet integrated) ↗
                                         ↕
                               Key Vault  |  Application Insights
```

All compute sits in the **app subnet**; Cosmos DB is reachable only via a **private endpoint** in the **db subnet**. APIM lives in its own **apim subnet** in Internal mode, so the gateway is never exposed directly to the internet — route through a Front Door or Application Gateway in production if public ingress is required.

---

## Prerequisites

| Tool | Version |
|------|---------|
| Terraform | ≥ 1.5 |
| Azure CLI | ≥ 2.55 |
| Azure DevOps | Any |

---

## One-Time Bootstrap (run once per subscription)

```bash
# 1. Create the Terraform state storage account
az group create -n rg-tfstate -l eastus

az storage account create \
  --name stterraformstate001 \
  --resource-group rg-tfstate \
  --sku Standard_LRS \
  --min-tls-version TLS1_2 \
  --https-only true

az storage container create \
  --name tfstate \
  --account-name stterraformstate001

# 2. Enable versioning and soft delete on the blob container
az storage account blob-service-properties update \
  --account-name stterraformstate001 \
  --enable-versioning true \
  --enable-delete-retention true \
  --delete-retention-days 30

# 3. Create a service principal (or use a Managed Identity / OIDC Workload Identity)
az ad sp create-for-rbac \
  --name sp-terraform-dev \
  --role Contributor \
  --scopes /subscriptions/<SUBSCRIPTION_ID>
```

---

## Local Development Workflow

```bash
cd infra

# Copy and fill in the example vars file
cp terraform.tfvars.example terraform.tfvars

# Authenticate
az login
az account set --subscription <SUBSCRIPTION_ID>

# Init (uses Azure Storage backend)
terraform init \
  -backend-config="resource_group_name=rg-tfstate" \
  -backend-config="storage_account_name=stterraformstate001" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=dev.terraform.tfstate"

# Plan
terraform plan \
  -var-file="dev.tfvars" \
  -var="subscription_id=<ID>" \
  -var="tenant_id=<ID>" \
  -var="apim_publisher_email=you@company.com" \
  -out=tfplan

# Apply
terraform apply tfplan

# Destroy (dev only!)
terraform destroy -var-file="dev.tfvars" ...
```

---

## Azure DevOps Pipeline Setup

### Step 1 – Import pipeline
1. Go to **Pipelines → New Pipeline → Azure Repos Git** → select repo → **Existing YAML file** → `/infra/azure-pipelines.yml`

### Step 2 – Create Service Connections (one per environment)
Settings → Service Connections → New → **Azure Resource Manager → Workload Identity (OIDC)**
- `sc-azure-dev`
- `sc-azure-test`
- `sc-azure-prod`

### Step 3 – Create Variable Groups (Pipelines → Library)

**`terraform-global`**
| Variable | Value |
|----------|-------|
| TF_VERSION | 1.7.5 |

**`terraform-dev` / `terraform-test` / `terraform-prod`** (mark sensitive values as secret)
| Variable | Notes |
|----------|-------|
| ARM_TENANT_ID | Azure AD tenant ID |
| ARM_SUBSCRIPTION_ID | Subscription ID |

### Step 4 – Create Azure DevOps Environments
Pipelines → Environments → New:
- `dev`  (no approval required)
- `test` (add **Approvals** check → select reviewers)
- `prod` (add **Approvals** check → require 2 reviewers)

### Step 5 – Store sensitive variables in Key Vault
The pipeline reads these secrets via the `AzureKeyVault@2` task:
| Secret name | Content |
|-------------|---------|
| `subscription-id` | Azure subscription GUID |
| `tenant-id` | Azure AD tenant GUID |
| `apim-publisher-email` | Publisher contact email |

---

## Module Reference

| Module | Resources created |
|--------|-------------------|
| `resource_group` | Resource group |
| `monitoring` | Log Analytics Workspace, Application Insights, Action Group, Metric Alert |
| `network` | VNet, 3 subnets, 3 NSGs, NSG associations, diagnostic settings |
| `key_vault` | Key Vault (RBAC mode, soft delete, private network ACL) |
| `app_service` | App Service Plan, Linux Web App, Autoscale setting, diagnostic settings |
| `function_app` | Storage Account, Elastic Premium Plan, Linux Function App, Autoscale, diagnostic settings |
| `cosmosdb` | Cosmos DB account, SQL databases, containers, private DNS zone, private endpoint |
| `api_management` | APIM instance (Internal VNet), App Insights logger, backend, global policy |

---

## Security Controls Summary

| Control | Implementation |
|---------|---------------|
| HTTPS only | Enforced on App Service, Function App, Storage Account, APIM policy |
| TLS 1.2+ | `min_tls_version = "1.2"` everywhere; APIM security block disables TLS 1.0/SSL 3.0 |
| Secrets management | All secrets stored in Key Vault; apps reference via `@Microsoft.KeyVault(...)` app setting syntax |
| RBAC least privilege | Apps get `Key Vault Secrets User`; Terraform SP gets `Key Vault Administrator` (scoped to KV only) |
| No public DB access | Cosmos DB `public_network_access_enabled = false` + private endpoint in db subnet |
| Managed Identity | System-assigned identity on App Service, Function App, and APIM |
| Diagnostic logs | Enabled on all services → Log Analytics Workspace |
