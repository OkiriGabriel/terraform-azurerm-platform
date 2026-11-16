output "action_group_id" {
  description = "ID of the action group. Reuse it for additional alert rules."
  value       = azurerm_monitor_action_group.this.id
}

output "metric_alert_ids" {
  description = "Map of metric alert keys to alert rule IDs."
  value       = { for k, v in azurerm_monitor_metric_alert.this : k => v.id }
}

output "service_health_alert_id" {
  description = "ID of the Service Health alert (null when disabled)."
  value       = try(azurerm_monitor_activity_log_alert.service_health[0].id, null)
}
