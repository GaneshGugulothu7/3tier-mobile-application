resource "azurerm_api_management" "this" {
  name                = "apim-${var.name_prefix}"
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_name      = var.publisher_name
  publisher_email     = var.publisher_email
  sku_name            = "${var.apim_sku}_1"   # e.g. "Developer_1"

  # VNet integration (Internal mode keeps gateway off the public internet)
  virtual_network_type = "Internal"
  virtual_network_configuration {
    subnet_id = var.subnet_id
  }

  identity {
    type = "SystemAssigned"
  }

  # Enforce minimum TLS version
  protocols {
    enable_http2 = true
  }

  security {
    enable_backend_tls10      = false
    enable_backend_ssl30      = false
    enable_frontend_tls10     = false
    enable_frontend_ssl30     = false
    tls_ecdhe_ecdsa_with_aes128_cbc_sha_ciphers_enabled = false
    tls_ecdhe_ecdsa_with_aes256_cbc_sha_ciphers_enabled = false
    tls_ecdhe_rsa_with_aes128_cbc_sha_ciphers_enabled   = false
    tls_ecdhe_rsa_with_aes256_cbc_sha_ciphers_enabled   = false
    tls_rsa_with_aes128_cbc_sha256_ciphers_enabled       = false
    tls_rsa_with_aes128_cbc_sha_ciphers_enabled          = false
    tls_rsa_with_aes256_cbc_sha256_ciphers_enabled       = false
    tls_rsa_with_aes256_cbc_sha_ciphers_enabled          = false
  }

  tags = var.tags
}

# ─── Application Insights logger ──────────────────────────────────────────────
resource "azurerm_api_management_logger" "this" {
  name                = "appi-logger-${var.name_prefix}"
  api_management_name = azurerm_api_management.this.name
  resource_group_name = var.resource_group_name
  resource_id         = var.app_insights_id

  application_insights {
    instrumentation_key = var.app_insights_key
  }
}

# ─── Named Value: backend base URL ───────────────────────────────────────────
resource "azurerm_api_management_named_value" "backend_url" {
  name                = "backend-base-url"
  api_management_name = azurerm_api_management.this.name
  resource_group_name = var.resource_group_name
  display_name        = "backend-base-url"
  value               = "https://${var.backend_app_hostname}"
  secret              = false
}

# ─── Backend pointing to App Service ─────────────────────────────────────────
resource "azurerm_api_management_backend" "app_service" {
  name                = "backend-app-service"
  api_management_name = azurerm_api_management.this.name
  resource_group_name = var.resource_group_name
  protocol            = "http"
  url                 = "https://${var.backend_app_hostname}"

  tls {
    validate_certificate_chain = true
    validate_certificate_name  = true
  }
}

# ─── Global policy: enforce HTTPS, add correlation ID ─────────────────────────
resource "azurerm_api_management_policy" "global" {
  api_management_id = azurerm_api_management.this.id

  xml_content = <<XML
<policies>
  <inbound>
    <set-header name="X-Correlation-Id" exists-action="skip">
      <value>@(Guid.NewGuid().ToString())</value>
    </set-header>
    <cors>
      <allowed-origins>
        <origin>*</origin>
      </allowed-origins>
      <allowed-methods>
        <method>GET</method>
        <method>POST</method>
        <method>PUT</method>
        <method>DELETE</method>
        <method>OPTIONS</method>
      </allowed-methods>
      <allowed-headers>
        <header>*</header>
      </allowed-headers>
    </cors>
  </inbound>
  <backend>
    <forward-request />
  </backend>
  <outbound>
    <set-header name="X-Powered-By" exists-action="delete" />
    <set-header name="X-AspNet-Version" exists-action="delete" />
  </outbound>
  <on-error>
    <base />
  </on-error>
</policies>
XML
}

# ─── Diagnostic Settings ──────────────────────────────────────────────────────
resource "azurerm_monitor_diagnostic_setting" "apim" {
  name                       = "diag-apim-${var.name_prefix}"
  target_resource_id         = azurerm_api_management.this.id
  log_analytics_workspace_id = var.log_analytics_id

  enabled_log { category = "GatewayLogs" }
  enabled_log { category = "WebSocketConnectionLogs" }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
