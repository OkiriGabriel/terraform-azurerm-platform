variable "name_prefix" {
  description = "Prefix for alert resource names (e.g. \"example-dev\")."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the action group and alert rules."
  type        = string
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------
# Notifications
# ---------------------------------------------------------------------------
variable "action_group_short_name" {
  description = "Short name shown in notifications (max 12 characters)."
  type        = string
  default     = "infra-alert"

  validation {
    condition     = length(var.action_group_short_name) > 0 && length(var.action_group_short_name) <= 12
    error_message = "action_group_short_name must be 1-12 characters."
  }
}

variable "email_receivers" {
  description = "Email addresses that receive alerts, keyed by a short name (e.g. { devops = \"devops@example.com\" })."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for e in values(var.email_receivers) : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", e))])
    error_message = "Every email_receivers value must be a valid email address."
  }
}

variable "webhook_receivers" {
  description = "Optional webhooks (e.g. Teams or Slack incoming webhooks), keyed by name."
  type        = map(string)
  default     = {}
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Metric alerts
# ---------------------------------------------------------------------------
variable "metric_alerts" {
  description = <<-EOT
    Map of metric alerts. Each entry targets one resource (scope_id) and one metric.
    severity: 0 = Critical, 1 = Error, 2 = Warning, 3 = Informational, 4 = Verbose.
  EOT
  type = map(object({
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
  }))
  default = {}

  validation {
    condition     = alltrue([for a in values(var.metric_alerts) : contains(["Average", "Count", "Minimum", "Maximum", "Total"], a.aggregation)])
    error_message = "aggregation must be one of Average, Count, Minimum, Maximum, Total."
  }

  validation {
    condition     = alltrue([for a in values(var.metric_alerts) : contains(["Equals", "GreaterThan", "GreaterThanOrEqual", "LessThan", "LessThanOrEqual"], a.operator)])
    error_message = "operator must be one of Equals, GreaterThan, GreaterThanOrEqual, LessThan, LessThanOrEqual."
  }

  validation {
    condition     = alltrue([for a in values(var.metric_alerts) : a.severity >= 0 && a.severity <= 4])
    error_message = "severity must be between 0 and 4."
  }
}

# ---------------------------------------------------------------------------
# Service Health
# ---------------------------------------------------------------------------
variable "service_health_enabled" {
  description = "Alert on Azure Service Health incidents and maintenance affecting the subscription (free)."
  type        = bool
  default     = true
}

variable "subscription_id" {
  description = "Subscription ID for the Service Health alert scope."
  type        = string
  default     = null
}

variable "service_health_locations" {
  description = "Regions to watch for Service Health events (e.g. [\"Central US\", \"Global\"]). Empty watches all."
  type        = list(string)
  default     = []
}
