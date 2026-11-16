# ---------------------------------------------------------------------------
# Action group: who gets notified
# ---------------------------------------------------------------------------
resource "azurerm_monitor_action_group" "this" {
  name                = "${var.name_prefix}-alerts-ag"
  resource_group_name = var.resource_group_name
  short_name          = var.action_group_short_name
  tags                = var.tags

  dynamic "email_receiver" {
    for_each = var.email_receivers
    content {
      name                    = email_receiver.key
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }

  dynamic "webhook_receiver" {
    for_each = nonsensitive(toset(keys(var.webhook_receivers)))
    content {
      name                    = webhook_receiver.value
      service_uri             = var.webhook_receivers[webhook_receiver.value]
      use_common_alert_schema = true
    }
  }
}

# ---------------------------------------------------------------------------
# Metric alerts
# ---------------------------------------------------------------------------
resource "azurerm_monitor_metric_alert" "this" {
  for_each = var.metric_alerts

  name                = "${var.name_prefix}-${each.key}"
  resource_group_name = var.resource_group_name
  scopes              = [each.value.scope_id]
  description         = each.value.description
  severity            = each.value.severity
  frequency           = each.value.frequency
  window_size         = each.value.window_size
  auto_mitigate       = true
  tags                = var.tags

  criteria {
    metric_namespace = each.value.metric_namespace
    metric_name      = each.value.metric_name
    aggregation      = each.value.aggregation
    operator         = each.value.operator
    threshold        = each.value.threshold

    dynamic "dimension" {
      for_each = each.value.dimensions
      content {
        name     = dimension.value.name
        operator = dimension.value.operator
        values   = dimension.value.values
      }
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.this.id
  }
}

# ---------------------------------------------------------------------------
# Azure Service Health (outages, planned maintenance, security advisories)
# ---------------------------------------------------------------------------
resource "azurerm_monitor_activity_log_alert" "service_health" {
  count = var.service_health_enabled ? 1 : 0

  name                = "${var.name_prefix}-service-health"
  resource_group_name = var.resource_group_name
  location            = "global"
  scopes              = ["/subscriptions/${var.subscription_id}"]
  description         = "Azure Service Health incidents, maintenance and advisories affecting this subscription."
  tags                = var.tags

  criteria {
    category = "ServiceHealth"

    service_health {
      events    = ["Incident", "Maintenance", "Security", "ActionRequired"]
      locations = length(var.service_health_locations) > 0 ? var.service_health_locations : null
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.this.id
  }
}

check "receivers" {
  assert {
    condition     = length(var.email_receivers) > 0 || length(nonsensitive(keys(var.webhook_receivers))) > 0
    error_message = "No email_receivers or webhook_receivers are configured, so alerts will fire but nobody will be notified."
  }

  assert {
    condition     = !var.service_health_enabled || var.subscription_id != null
    error_message = "subscription_id is required when service_health_enabled is true."
  }
}
