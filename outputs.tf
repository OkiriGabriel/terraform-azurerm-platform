output "resource_group_name" {
  description = "Name of the resource group."
  value       = local.resource_group.name
}

output "resource_group_id" {
  description = "ID of the resource group."
  value       = local.resource_group.id
}

output "name_suffix" {
  description = "Suffix used to make global names unique."
  value       = local.suffix
}

output "log_analytics_workspace_id" {
  description = "ID of the Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.this.id
}

output "ai_ml" {
  description = "AI/ML endpoints and IDs (null when disabled)."
  value = var.ai_ml.enabled ? {
    workspace_name    = module.ai_ml[0].workspace_name
    workspace_id      = module.ai_ml[0].workspace_id
    openai_endpoint   = module.ai_ml[0].openai_endpoint
    openai_account_id = module.ai_ml[0].openai_account_id
    search_endpoint   = module.ai_ml[0].search_endpoint
  } : null
}

output "postgresql" {
  description = "PostgreSQL connection details (null when disabled). The password is in postgresql_administrator_password."
  value = var.postgresql.enabled ? {
    server_id                        = module.postgresql[0].server_id
    fqdn                             = module.postgresql[0].fqdn
    administrator_login              = module.postgresql[0].administrator_login
    administrator_password_secret_id = module.postgresql[0].administrator_password_secret_id
    database_names                   = module.postgresql[0].database_names
  } : null
}

output "postgresql_administrator_password" {
  description = "Generated PostgreSQL administrator password (null when disabled)."
  value       = try(module.postgresql[0].administrator_password, null)
  sensitive   = true
}

output "alerts_action_group_id" {
  description = "Action group ID for adding your own alert rules (null when alerts are disabled)."
  value       = try(module.alerts[0].action_group_id, null)
}
