# Monitoring alerts: email notifications for platform health.
# Toggle per environment with alert_config.enabled in vars_enviro_dev.tf / var_enviro_prod.tf.
# Cost: metric alerts are about $0.10 per rule per month; Service Health alerts and email are free.

locals {
  database_enabled = local.current_env.database_config.enabled
  openai_enabled   = local.current_env.ai_ml_config.enabled && local.current_env.ai_ml_config.openai_enabled

  # Every candidate alert. "enabled" drops alerts for features that are switched off.
  # severity: 0 Critical, 1 Error, 2 Warning, 3 Informational.
  all_metric_alerts = {
    redis-server-load = {
      enabled          = true
      scope_id         = module.redis.redis_id["main"]
      metric_namespace = "Microsoft.Cache/redis"
      metric_name      = "serverLoad"
      aggregation      = "Maximum"
      operator         = "GreaterThan"
      threshold        = 80
      severity         = 2
      description      = "Redis server load is above 80%. Consider scaling up the cache."
    }
    redis-memory = {
      enabled          = true
      scope_id         = module.redis.redis_id["main"]
      metric_namespace = "Microsoft.Cache/redis"
      metric_name      = "usedmemorypercentage"
      aggregation      = "Maximum"
      operator         = "GreaterThan"
      threshold        = 85
      severity         = 2
      description      = "Redis memory usage is above 85%. Keys may be evicted."
    }
    keyvault-availability = {
      enabled          = true
      scope_id         = module.key_vault.key_vault_id
      metric_namespace = "Microsoft.KeyVault/vaults"
      metric_name      = "Availability"
      aggregation      = "Average"
      operator         = "LessThan"
      threshold        = 99
      severity         = 1
      description      = "Platform Key Vault availability dropped below 99%."
    }
    secrets-vault-availability = {
      enabled          = true
      scope_id         = azurerm_key_vault.secrets_vault.id
      metric_namespace = "Microsoft.KeyVault/vaults"
      metric_name      = "Availability"
      aggregation      = "Average"
      operator         = "LessThan"
      threshold        = 99
      severity         = 1
      description      = "Application secrets Key Vault availability dropped below 99%."
    }
    backend-restarts = {
      enabled          = true
      scope_id         = module.container_apps_v2.backend_container_app_id
      metric_namespace = "Microsoft.App/containerApps"
      metric_name      = "RestartCount"
      aggregation      = "Total"
      operator         = "GreaterThan"
      threshold        = 3
      severity         = 2
      description      = "Backend container app restarted more than 3 times in 15 minutes (crash loop?)."
    }
    frontend-restarts = {
      enabled          = true
      scope_id         = module.container_apps_v2.frontend_container_app_id
      metric_namespace = "Microsoft.App/containerApps"
      metric_name      = "RestartCount"
      aggregation      = "Total"
      operator         = "GreaterThan"
      threshold        = 3
      severity         = 2
      description      = "Frontend container app restarted more than 3 times in 15 minutes (crash loop?)."
    }
    postgresql-down = {
      enabled          = local.database_enabled
      scope_id         = try(module.postgresql[0].server_id, "")
      metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
      metric_name      = "is_db_alive"
      aggregation      = "Minimum"
      operator         = "LessThan"
      threshold        = 1
      severity         = 0
      description      = "PostgreSQL server is not responding."
    }
    postgresql-cpu = {
      enabled          = local.database_enabled
      scope_id         = try(module.postgresql[0].server_id, "")
      metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
      metric_name      = "cpu_percent"
      aggregation      = "Average"
      operator         = "GreaterThan"
      threshold        = 80
      severity         = 2
      description      = "PostgreSQL CPU is above 80%."
    }
    postgresql-memory = {
      enabled          = local.database_enabled
      scope_id         = try(module.postgresql[0].server_id, "")
      metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
      metric_name      = "memory_percent"
      aggregation      = "Average"
      operator         = "GreaterThan"
      threshold        = 90
      severity         = 2
      description      = "PostgreSQL memory is above 90%."
    }
    postgresql-storage = {
      enabled          = local.database_enabled
      scope_id         = try(module.postgresql[0].server_id, "")
      metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
      metric_name      = "storage_percent"
      aggregation      = "Average"
      operator         = "GreaterThan"
      threshold        = 85
      severity         = 1
      description      = "PostgreSQL storage is above 85% full."
    }
  }

  openai_throttling_alert = {
    openai-throttling = {
      scope_id         = try(module.ai_ml[0].openai_account_id, "")
      metric_namespace = "Microsoft.CognitiveServices/accounts"
      metric_name      = "AzureOpenAIRequests"
      aggregation      = "Total"
      operator         = "GreaterThan"
      threshold        = 10
      severity         = 2
      description      = "Azure OpenAI returned more than 10 throttled (HTTP 429) responses in 15 minutes. Raise deployment capacity."
      dimensions       = [{ name = "StatusCode", values = ["429"] }]
    }
  }

  metric_alerts = merge(
    { for k, v in local.all_metric_alerts : k => {
      scope_id         = v.scope_id
      metric_namespace = v.metric_namespace
      metric_name      = v.metric_name
      aggregation      = v.aggregation
      operator         = v.operator
      threshold        = v.threshold
      severity         = v.severity
      description      = v.description
    } if v.enabled },
    { for k, v in local.openai_throttling_alert : k => v if local.openai_enabled },
  )
}

module "alerts" {
  source = "./modules/alerts"
  count  = local.current_env.alert_config.enabled ? 1 : 0

  name_prefix         = "example-${local.current_env.environment}"
  resource_group_name = module.resource_group.name
  tags                = merge(local.current_env.tags, { Workload = "monitoring" })

  email_receivers          = local.current_env.alert_config.email_receivers
  service_health_enabled   = local.current_env.alert_config.service_health_enabled
  service_health_locations = local.current_env.alert_config.service_health_locations
  subscription_id          = local.current_env.subscription_id

  metric_alerts = local.metric_alerts
}

output "alerts_action_group_id" {
  description = "Action group used by platform alerts (null when alerts are disabled)."
  value       = try(module.alerts[0].action_group_id, null)
}
