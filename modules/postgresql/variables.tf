# ---------------------------------------------------------------------------
# Core
# ---------------------------------------------------------------------------
variable "name" {
  description = "Globally unique server name (3-63 lowercase letters, numbers and hyphens)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.name))
    error_message = "name must be 3-63 characters of lowercase letters, numbers and hyphens, and must not start or end with a hyphen."
  }
}

variable "resource_group_name" {
  description = "Resource group for the server."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Server
# ---------------------------------------------------------------------------
variable "postgresql_version" {
  description = "PostgreSQL major version."
  type        = string
  default     = "16"

  validation {
    condition     = contains(["13", "14", "15", "16", "17"], var.postgresql_version)
    error_message = "postgresql_version must be one of 13, 14, 15, 16, 17."
  }
}

variable "sku_name" {
  description = "SKU as <tier>_<size>. B_Standard_B1ms (Burstable) is the cheapest; GP_Standard_D2ds_v5 for production."
  type        = string
  default     = "B_Standard_B1ms"

  validation {
    condition     = can(regex("^(B|GP|MO)_Standard_", var.sku_name))
    error_message = "sku_name must start with B_Standard_, GP_Standard_ or MO_Standard_."
  }
}

variable "storage_mb" {
  description = "Storage size in MB (32768 = 32 GB minimum)."
  type        = number
  default     = 32768

  validation {
    condition     = contains([32768, 65536, 131072, 262144, 524288, 1048576, 2097152, 4193280, 4194304, 8388608, 16777216, 33553408], var.storage_mb)
    error_message = "storage_mb must be a supported size such as 32768, 65536 or 131072."
  }
}

variable "auto_grow_enabled" {
  description = "Grow storage automatically when it is nearly full."
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Backup retention in days (7-35)."
  type        = number
  default     = 7

  validation {
    condition     = var.backup_retention_days >= 7 && var.backup_retention_days <= 35
    error_message = "backup_retention_days must be between 7 and 35."
  }
}

variable "geo_redundant_backup_enabled" {
  description = "Store backups in the paired region (extra cost; cannot be changed after creation)."
  type        = bool
  default     = false
}

variable "high_availability_mode" {
  description = "null (off), \"SameZone\" or \"ZoneRedundant\". Not available on Burstable SKUs; doubles compute cost."
  type        = string
  default     = null

  validation {
    condition     = var.high_availability_mode == null || contains(["SameZone", "ZoneRedundant"], coalesce(var.high_availability_mode, "x"))
    error_message = "high_availability_mode must be null, SameZone or ZoneRedundant."
  }
}

variable "zone" {
  description = "Availability zone for the primary server (null lets Azure choose)."
  type        = string
  default     = null
}

variable "databases" {
  description = "Names of databases to create on the server."
  type        = list(string)
  default     = []
}

variable "server_configurations" {
  description = "PostgreSQL server parameters, e.g. { \"log_min_duration_statement\" = \"500\" }."
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Authentication
# ---------------------------------------------------------------------------
variable "administrator_login" {
  description = "Administrator user name (the password is generated)."
  type        = string
  default     = "psqladmin"

  validation {
    condition     = !contains(["azure_superuser", "azure_pg_admin", "admin", "administrator", "root", "guest", "public"], lower(var.administrator_login))
    error_message = "administrator_login cannot be a reserved name such as admin, root or azure_superuser."
  }
}

variable "entra_auth_enabled" {
  description = "Enable Microsoft Entra ID authentication alongside password authentication."
  type        = bool
  default     = true
}

variable "tenant_id" {
  description = "Entra tenant ID (required when entra_auth_enabled is true)."
  type        = string
  default     = null
}

variable "entra_administrator" {
  description = "Optional Entra administrator: object_id, principal_name and principal_type (User, Group or ServicePrincipal)."
  type = object({
    object_id      = string
    principal_name = string
    principal_type = optional(string, "Group")
  })
  default = null
}

variable "store_password_in_key_vault" {
  description = "Store the generated administrator password in Key Vault (key_vault_id must be set)."
  type        = bool
  default     = false
}

variable "key_vault_id" {
  description = "Key Vault that receives the administrator password secret."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------
variable "public_network_access_enabled" {
  description = "Allow access over the public internet (firewall_rules then apply). Keep false and use a private endpoint."
  type        = bool
  default     = false
}

variable "firewall_rules" {
  description = "Public firewall rules (only used when public_network_access_enabled is true)."
  type = map(object({
    start_ip_address = string
    end_ip_address   = string
  }))
  default = {}
}

variable "private_endpoint_enabled" {
  description = "Create a private endpoint in private_endpoint_subnet_id."
  type        = bool
  default     = true
}

variable "private_endpoint_subnet_id" {
  description = "Subnet for the private endpoint."
  type        = string
  default     = null
}

variable "private_dns_zone_vnet_ids" {
  description = "VNets to link to the privatelink.postgres.database.azure.com zone, keyed by a short name (e.g. hub, spoke1)."
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Diagnostics
# ---------------------------------------------------------------------------
variable "diagnostics_enabled" {
  description = "Send server logs and metrics to Log Analytics."
  type        = bool
  default     = true
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace for diagnostics."
  type        = string
  default     = null
}
