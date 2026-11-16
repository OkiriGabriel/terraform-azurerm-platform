# PostgreSQL Flexible Server, reachable privately from the hub and spoke VNets.
# Toggle per environment with database_config.enabled in vars_enviro_dev.tf / var_enviro_prod.tf.

module "postgresql" {
  source = "../../modules/postgresql"
  count  = local.current_env.database_config.enabled ? 1 : 0

  name                = "example-${local.current_env.environment}-psql"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  tags                = merge(local.current_env.tags, { Workload = "database" })

  postgresql_version           = local.current_env.database_config.version
  sku_name                     = local.current_env.database_config.sku_name
  storage_mb                   = local.current_env.database_config.storage_mb
  auto_grow_enabled            = local.current_env.database_config.auto_grow_enabled
  backup_retention_days        = local.current_env.database_config.backup_retention_days
  geo_redundant_backup_enabled = local.current_env.database_config.geo_redundant_backup_enabled
  high_availability_mode       = local.current_env.database_config.high_availability_mode
  databases                    = local.current_env.database_config.databases
  server_configurations        = local.current_env.database_config.server_configurations

  administrator_login = local.current_env.database_config.admin_username
  entra_auth_enabled  = true
  tenant_id           = local.current_env.tenant_id

  # Generated admin password is stored in the platform Key Vault.
  store_password_in_key_vault = true
  key_vault_id                = module.key_vault.key_vault_id

  # Private endpoint in the workload subnet; DNS resolves from hub and spoke.
  public_network_access_enabled = false
  private_endpoint_enabled      = true
  private_endpoint_subnet_id    = module.spoke1.subnet_ids["WorkloadSubnet"]
  private_dns_zone_vnet_ids = {
    hub    = module.hub.vnet_id
    spoke1 = module.spoke1.vnet_id
  }

  diagnostics_enabled        = true
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
}

output "postgresql_fqdn" {
  description = "PostgreSQL server FQDN (null when the database is disabled)."
  value       = try(module.postgresql[0].fqdn, null)
}

output "postgresql_password_secret_id" {
  description = "Key Vault secret holding the PostgreSQL admin password (null when disabled)."
  value       = try(module.postgresql[0].administrator_password_secret_id, null)
}
