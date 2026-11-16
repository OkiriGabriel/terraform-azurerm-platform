data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  count = var.name_suffix == null ? 1 : 0

  length  = 4
  special = false
  upper   = false
}

locals {
  suffix = coalesce(var.name_suffix, try(random_string.suffix[0].result, null))

  # Globally unique base name, e.g. "app-dev-x7k2".
  base_name = "${var.name_prefix}-${local.suffix}"

  # Alphanumeric variant for storage accounts, e.g. "appdevx7k2".
  compact_name = replace(local.base_name, "-", "")

  resource_group_name = coalesce(var.resource_group_name, "${var.name_prefix}-rg")
  resource_group      = var.create_resource_group ? azurerm_resource_group.this[0] : data.azurerm_resource_group.existing[0]

  tags = merge({ ManagedBy = "Terraform", Module = "terraform-azurerm-platform" }, var.tags)
}

# ---------------------------------------------------------------------------
# Foundation
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "this" {
  count = var.create_resource_group ? 1 : 0

  name     = local.resource_group_name
  location = var.location
  tags     = local.tags
}

data "azurerm_resource_group" "existing" {
  count = var.create_resource_group ? 0 : 1

  name = local.resource_group_name
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = "${local.base_name}-law"
  resource_group_name = local.resource_group.name
  location            = var.location
  sku                 = var.log_analytics.sku
  retention_in_days   = var.log_analytics.retention_days
  tags                = local.tags
}

# ---------------------------------------------------------------------------
# AI / ML
# ---------------------------------------------------------------------------
module "ai_ml" {
  source = "./modules/ai-ml"
  count  = var.ai_ml.enabled ? 1 : 0

  name_prefix                = local.base_name
  resource_group_name        = local.resource_group.name
  location                   = var.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  tags                       = merge(local.tags, { Workload = "ai-ml" })

  storage_account_name     = "${local.compact_name}mlsa"
  storage_replication_type = var.ai_ml.storage_replication_type
  key_vault_name           = "${local.base_name}-mlkv"
  container_registry_id    = var.ai_ml.container_registry_id
  high_business_impact     = var.ai_ml.high_business_impact

  public_network_access_enabled = var.ai_ml.public_network_access_enabled
  private_endpoints_enabled     = var.ai_ml.private_endpoints_enabled
  private_endpoint_subnet_id    = var.network.private_endpoint_subnet_id
  compute_clusters              = var.ai_ml.compute_clusters

  openai_enabled     = var.ai_ml.openai_enabled
  openai_location    = var.ai_ml.openai_location
  openai_deployments = var.ai_ml.openai_deployments

  search_enabled         = var.ai_ml.search_enabled
  search_sku             = var.ai_ml.search_sku
  search_replica_count   = var.ai_ml.search_replica_count
  search_partition_count = var.ai_ml.search_partition_count
}

# ---------------------------------------------------------------------------
# PostgreSQL
# ---------------------------------------------------------------------------
module "postgresql" {
  source = "./modules/postgresql"
  count  = var.postgresql.enabled ? 1 : 0

  name                = "${local.base_name}-psql"
  resource_group_name = local.resource_group.name
  location            = var.location
  tags                = merge(local.tags, { Workload = "database" })

  postgresql_version           = var.postgresql.version
  sku_name                     = var.postgresql.sku_name
  storage_mb                   = var.postgresql.storage_mb
  auto_grow_enabled            = var.postgresql.auto_grow_enabled
  backup_retention_days        = var.postgresql.backup_retention_days
  geo_redundant_backup_enabled = var.postgresql.geo_redundant_backup_enabled
  high_availability_mode       = var.postgresql.high_availability_mode
  databases                    = var.postgresql.databases
  server_configurations        = var.postgresql.server_configurations

  administrator_login = var.postgresql.administrator_login
  entra_auth_enabled  = true
  tenant_id           = data.azurerm_client_config.current.tenant_id
  entra_administrator = var.postgresql.entra_administrator

  store_password_in_key_vault = var.postgresql.store_password_in_key_vault
  key_vault_id                = var.postgresql.key_vault_id

  public_network_access_enabled = var.postgresql.public_network_access_enabled
  firewall_rules                = var.postgresql.firewall_rules
  private_endpoint_enabled      = var.postgresql.private_endpoint_enabled
  private_endpoint_subnet_id    = var.network.private_endpoint_subnet_id
  private_dns_zone_vnet_ids     = var.network.private_dns_vnet_ids

  diagnostics_enabled        = true
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
}

# ---------------------------------------------------------------------------
# Alerts
# ---------------------------------------------------------------------------
locals {
  postgresql_alerts = {
    postgresql-down    = { metric_name = "is_db_alive", aggregation = "Minimum", operator = "LessThan", threshold = 1, severity = 0, description = "PostgreSQL server is not responding." }
    postgresql-cpu     = { metric_name = "cpu_percent", aggregation = "Average", operator = "GreaterThan", threshold = 80, severity = 2, description = "PostgreSQL CPU is above 80%." }
    postgresql-memory  = { metric_name = "memory_percent", aggregation = "Average", operator = "GreaterThan", threshold = 90, severity = 2, description = "PostgreSQL memory is above 90%." }
    postgresql-storage = { metric_name = "storage_percent", aggregation = "Average", operator = "GreaterThan", threshold = 85, severity = 1, description = "PostgreSQL storage is above 85% full." }
  }

  feature_alerts = merge(
    { for k, v in local.postgresql_alerts : k => merge(v, {
      scope_id         = module.postgresql[0].server_id
      metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
      dimensions       = []
    }) if var.postgresql.enabled },
    { for k in ["openai-throttling"] : k => {
      scope_id         = module.ai_ml[0].openai_account_id
      metric_namespace = "Microsoft.CognitiveServices/accounts"
      metric_name      = "AzureOpenAIRequests"
      aggregation      = "Total"
      operator         = "GreaterThan"
      threshold        = 10
      severity         = 2
      description      = "Azure OpenAI returned more than 10 throttled (HTTP 429) responses in 15 minutes."
      dimensions       = [{ name = "StatusCode", operator = "Include", values = ["429"] }]
    } if var.ai_ml.enabled && var.ai_ml.openai_enabled },
  )
}

module "alerts" {
  source = "./modules/alerts"
  count  = var.alerts.enabled ? 1 : 0

  name_prefix         = local.base_name
  resource_group_name = local.resource_group.name
  tags                = merge(local.tags, { Workload = "monitoring" })

  email_receivers          = var.alerts.email_receivers
  service_health_enabled   = var.alerts.service_health_enabled
  service_health_locations = var.alerts.service_health_locations
  subscription_id          = data.azurerm_client_config.current.subscription_id

  metric_alerts = merge(local.feature_alerts, var.alerts.extra_metric_alerts)
}
