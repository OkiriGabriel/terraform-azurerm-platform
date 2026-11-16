# ---------------------------------------------------------------------------
# Core
# ---------------------------------------------------------------------------
variable "name_prefix" {
  description = "Short prefix for all resource names, e.g. \"app-dev\" (2-14 lowercase letters, numbers, hyphens)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,13}$", var.name_prefix))
    error_message = "name_prefix must be 2-14 characters, start with a letter, and contain only lowercase letters, numbers and hyphens."
  }
}

variable "name_suffix" {
  description = "Suffix that makes globally unique names (storage, Key Vault, OpenAI, database). null generates a random 4-character suffix."
  type        = string
  default     = null

  validation {
    condition     = var.name_suffix == null || can(regex("^[a-z0-9]{1,4}$", coalesce(var.name_suffix, "x")))
    error_message = "name_suffix must be 1-4 lowercase letters or numbers."
  }
}

variable "location" {
  description = "Azure region for all resources (e.g. \"centralus\")."
  type        = string
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}

variable "create_resource_group" {
  description = "Create the resource group. Set to false to deploy into an existing one named resource_group_name."
  type        = bool
  default     = true
}

variable "resource_group_name" {
  description = "Resource group name. Defaults to \"<name_prefix>-rg\". Required when create_resource_group is false."
  type        = string
  default     = null
}

variable "log_analytics" {
  description = "Log Analytics workspace settings (used by diagnostics and Application Insights)."
  type = object({
    sku            = optional(string, "PerGB2018")
    retention_days = optional(number, 30)
  })
  default = {}

  validation {
    condition     = var.log_analytics.retention_days >= 30 && var.log_analytics.retention_days <= 730
    error_message = "log_analytics.retention_days must be between 30 and 730."
  }
}

# ---------------------------------------------------------------------------
# Networking (bring your own VNet)
# ---------------------------------------------------------------------------
variable "network" {
  description = <<-EOT
    Private networking for optional features.
    private_endpoint_subnet_id: subnet where private endpoints are placed.
    private_dns_vnet_ids: VNets (by short name) linked to the PostgreSQL private DNS zone so the server resolves privately.
  EOT
  type = object({
    private_endpoint_subnet_id = optional(string)
    private_dns_vnet_ids       = optional(map(string), {})
  })
  default = {}
}

# ---------------------------------------------------------------------------
# Feature: AI / ML
# ---------------------------------------------------------------------------
variable "ai_ml" {
  description = "Azure Machine Learning, Azure OpenAI and Azure AI Search. Disabled by default. See modules/ai-ml/README.md."
  type = object({
    enabled                       = optional(bool, false)
    public_network_access_enabled = optional(bool, false)
    private_endpoints_enabled     = optional(bool, false)
    storage_replication_type      = optional(string, "ZRS")
    high_business_impact          = optional(bool, false)
    container_registry_id         = optional(string)
    compute_clusters = optional(map(object({
      vm_size              = string
      vm_priority          = optional(string, "LowPriority")
      min_nodes            = optional(number, 0)
      max_nodes            = optional(number, 2)
      idle_before_scale_in = optional(string, "PT15M")
      subnet_id            = optional(string)
    })), {})
    openai_enabled  = optional(bool, true)
    openai_location = optional(string)
    openai_deployments = optional(map(object({
      model_name    = string
      model_version = string
      sku_name      = optional(string, "Standard")
      capacity      = optional(number, 10)
    })), {})
    search_enabled         = optional(bool, true)
    search_sku             = optional(string, "basic")
    search_replica_count   = optional(number, 1)
    search_partition_count = optional(number, 1)
  })
  default = {}
}

# ---------------------------------------------------------------------------
# Feature: PostgreSQL
# ---------------------------------------------------------------------------
variable "postgresql" {
  description = "PostgreSQL Flexible Server. Disabled by default. See modules/postgresql/README.md."
  type = object({
    enabled                       = optional(bool, false)
    version                       = optional(string, "16")
    sku_name                      = optional(string, "B_Standard_B1ms")
    storage_mb                    = optional(number, 32768)
    auto_grow_enabled             = optional(bool, true)
    backup_retention_days         = optional(number, 7)
    geo_redundant_backup_enabled  = optional(bool, false)
    high_availability_mode        = optional(string)
    databases                     = optional(list(string), ["app"])
    server_configurations         = optional(map(string), {})
    administrator_login           = optional(string, "psqladmin")
    public_network_access_enabled = optional(bool, false)
    private_endpoint_enabled      = optional(bool, true)
    firewall_rules = optional(map(object({
      start_ip_address = string
      end_ip_address   = string
    })), {})
    entra_administrator = optional(object({
      object_id      = string
      principal_name = string
      principal_type = optional(string, "Group")
    }))
    store_password_in_key_vault = optional(bool, false)
    key_vault_id                = optional(string)
  })
  default = {}
}

# ---------------------------------------------------------------------------
# Feature: Alerts
# ---------------------------------------------------------------------------
variable "alerts" {
  description = <<-EOT
    Email/webhook alerting. Disabled by default. Alerts for enabled features (PostgreSQL, OpenAI) are added
    automatically; add your own with extra_metric_alerts. See modules/alerts/README.md.
  EOT
  type = object({
    enabled                  = optional(bool, false)
    email_receivers          = optional(map(string), {})
    service_health_enabled   = optional(bool, true)
    service_health_locations = optional(list(string), [])
    extra_metric_alerts = optional(map(object({
      scope_id         = string
      metric_namespace = string
      metric_name      = string
      aggregation      = string
      operator         = string
      threshold        = number
      description      = string
      severity         = optional(number, 2)
      frequency        = optional(string, "PT5M")
      window_size      = optional(string, "PT15M")
      dimensions = optional(list(object({
        name     = string
        operator = optional(string, "Include")
        values   = list(string)
      })), [])
    })), {})
  })
  default = {}
}
