resource "random_password" "admin" {
  length           = 32
  special          = true
  override_special = "!#%*()-_=+[]{}:?"
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
  min_special      = 2
}

# ---------------------------------------------------------------------------
# Server
# ---------------------------------------------------------------------------
resource "azurerm_postgresql_flexible_server" "this" {
  #checkov:skip=CKV_AZURE_136:Geo-redundant backup is configurable (geo_redundant_backup_enabled); off by default to control cost
  #checkov:skip=CKV2_AZURE_57:Private endpoint is created by azurerm_private_endpoint.this when private_endpoint_enabled is true
  name                          = var.name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  version                       = var.postgresql_version
  sku_name                      = var.sku_name
  storage_mb                    = var.storage_mb
  auto_grow_enabled             = var.auto_grow_enabled
  backup_retention_days         = var.backup_retention_days
  geo_redundant_backup_enabled  = var.geo_redundant_backup_enabled
  zone                          = var.zone
  public_network_access_enabled = var.public_network_access_enabled
  administrator_login           = var.administrator_login
  administrator_password        = random_password.admin.result
  tags                          = var.tags

  authentication {
    password_auth_enabled         = true
    active_directory_auth_enabled = var.entra_auth_enabled
    tenant_id                     = var.entra_auth_enabled ? var.tenant_id : null
  }

  dynamic "high_availability" {
    for_each = var.high_availability_mode == null ? [] : [var.high_availability_mode]
    content {
      mode = high_availability.value
    }
  }

  lifecycle {
    # Azure may move the primary to the standby zone after a failover.
    ignore_changes = [zone, high_availability[0].standby_availability_zone]
  }
}

resource "azurerm_postgresql_flexible_server_database" "this" {
  for_each = toset(var.databases)

  name      = each.value
  server_id = azurerm_postgresql_flexible_server.this.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_postgresql_flexible_server_configuration" "this" {
  for_each = var.server_configurations

  name      = each.key
  server_id = azurerm_postgresql_flexible_server.this.id
  value     = each.value
}

resource "azurerm_postgresql_flexible_server_active_directory_administrator" "this" {
  count = var.entra_auth_enabled && var.entra_administrator != null ? 1 : 0

  server_name         = azurerm_postgresql_flexible_server.this.name
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  object_id           = var.entra_administrator.object_id
  principal_name      = var.entra_administrator.principal_name
  principal_type      = var.entra_administrator.principal_type
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "this" {
  for_each = var.public_network_access_enabled ? var.firewall_rules : {}

  name             = each.key
  server_id        = azurerm_postgresql_flexible_server.this.id
  start_ip_address = each.value.start_ip_address
  end_ip_address   = each.value.end_ip_address
}

# ---------------------------------------------------------------------------
# Secrets
# ---------------------------------------------------------------------------
resource "azurerm_key_vault_secret" "admin_password" {
  #checkov:skip=CKV_AZURE_41:Generated password is rotated by replacing random_password; no fixed expiry
  count = var.store_password_in_key_vault ? 1 : 0

  name         = "${var.name}-admin-password"
  value        = random_password.admin.result
  key_vault_id = var.key_vault_id
  content_type = "password"
  tags         = var.tags
}

# ---------------------------------------------------------------------------
# Private networking
# ---------------------------------------------------------------------------
resource "azurerm_private_dns_zone" "this" {
  count = var.private_endpoint_enabled ? 1 : 0

  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each = var.private_endpoint_enabled ? var.private_dns_zone_vnet_ids : {}

  name                  = "${var.name}-${each.key}-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.this[0].name
  virtual_network_id    = each.value
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_endpoint" "this" {
  count = var.private_endpoint_enabled ? 1 : 0

  name                = "${var.name}-pe"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "${var.name}-psc"
    private_connection_resource_id = azurerm_postgresql_flexible_server.this.id
    subresource_names              = ["postgresqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.this[0].id]
  }
}

# ---------------------------------------------------------------------------
# Diagnostics
# ---------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "this" {
  count = var.diagnostics_enabled ? 1 : 0

  name                       = "${var.name}-diag"
  target_resource_id         = azurerm_postgresql_flexible_server.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# ---------------------------------------------------------------------------
# Guardrails
# ---------------------------------------------------------------------------
check "configuration" {
  assert {
    condition     = !(var.high_availability_mode != null && startswith(var.sku_name, "B_"))
    error_message = "High availability is not supported on Burstable (B_) SKUs. Use a GP_ or MO_ SKU or set high_availability_mode = null."
  }

  assert {
    condition     = var.public_network_access_enabled || var.private_endpoint_enabled
    error_message = "Public access is disabled and no private endpoint is enabled: the server will be unreachable."
  }

  assert {
    condition     = !var.entra_auth_enabled || var.tenant_id != null
    error_message = "tenant_id is required when entra_auth_enabled is true."
  }
}
