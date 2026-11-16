output "server_id" {
  description = "ID of the PostgreSQL Flexible Server."
  value       = azurerm_postgresql_flexible_server.this.id
}

output "server_name" {
  description = "Name of the PostgreSQL Flexible Server."
  value       = azurerm_postgresql_flexible_server.this.name
}

output "fqdn" {
  description = "Server FQDN. With a private endpoint it resolves to the private IP inside linked VNets."
  value       = azurerm_postgresql_flexible_server.this.fqdn
}

output "administrator_login" {
  description = "Administrator user name."
  value       = azurerm_postgresql_flexible_server.this.administrator_login
}

output "administrator_password" {
  description = "Generated administrator password."
  value       = random_password.admin.result
  sensitive   = true
}

output "administrator_password_secret_id" {
  description = "Key Vault secret ID holding the administrator password (null when not stored)."
  value       = try(azurerm_key_vault_secret.admin_password[0].id, null)
}

output "database_names" {
  description = "Databases created on the server."
  value       = keys(azurerm_postgresql_flexible_server_database.this)
}

output "private_dns_zone_id" {
  description = "ID of the privatelink.postgres.database.azure.com zone (null when no private endpoint)."
  value       = try(azurerm_private_dns_zone.this[0].id, null)
}
