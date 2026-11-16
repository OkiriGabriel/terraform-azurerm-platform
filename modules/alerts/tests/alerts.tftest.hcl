# Unit tests for the alerts module. Run with: terraform test
# Uses a mocked provider, so no Azure credentials are required.

mock_provider "azurerm" {
  mock_resource "azurerm_monitor_action_group" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Insights/actionGroups/test-ag"
    }
  }
}

variables {
  name_prefix         = "test"
  resource_group_name = "rg-test"
  subscription_id     = "00000000-0000-0000-0000-000000000000"
  email_receivers     = { devops = "devops@example.com" }
}

run "action_group_and_service_health" {
  command = plan

  assert {
    condition     = length(azurerm_monitor_action_group.this.email_receiver) == 1
    error_message = "The email receiver should be configured."
  }

  assert {
    condition     = azurerm_monitor_activity_log_alert.service_health[0].location == "global"
    error_message = "Service Health alert should be created by default in the global location."
  }

  assert {
    condition     = length(azurerm_monitor_metric_alert.this) == 0
    error_message = "No metric alerts should exist when none are configured."
  }
}

run "metric_alerts_with_dimensions" {
  command = plan

  variables {
    metric_alerts = {
      redis-server-load = {
        scope_id         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Cache/redis/test"
        metric_namespace = "Microsoft.Cache/redis"
        metric_name      = "serverLoad"
        aggregation      = "Maximum"
        operator         = "GreaterThan"
        threshold        = 80
        description      = "Redis server load is high."
      }
      openai-throttling = {
        scope_id         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.CognitiveServices/accounts/test"
        metric_namespace = "Microsoft.CognitiveServices/accounts"
        metric_name      = "AzureOpenAIRequests"
        aggregation      = "Total"
        operator         = "GreaterThan"
        threshold        = 10
        severity         = 1
        description      = "OpenAI requests are being throttled."
        dimensions       = [{ name = "StatusCode", values = ["429"] }]
      }
    }
  }

  assert {
    condition     = length(azurerm_monitor_metric_alert.this) == 2
    error_message = "Both metric alerts should be created."
  }

  assert {
    condition     = azurerm_monitor_metric_alert.this["redis-server-load"].severity == 2
    error_message = "Severity should default to 2 (Warning)."
  }

  assert {
    condition     = azurerm_monitor_metric_alert.this["openai-throttling"].criteria[0].dimension[0].values[0] == "429"
    error_message = "Dimension filters should be applied."
  }
}

run "service_health_can_be_disabled" {
  command = plan

  variables {
    service_health_enabled = false
  }

  assert {
    condition     = length(azurerm_monitor_activity_log_alert.service_health) == 0
    error_message = "Service Health alert should not be created when disabled."
  }
}

run "warns_without_receivers" {
  command = plan

  variables {
    email_receivers = {}
  }

  expect_failures = [check.receivers]
}

run "rejects_invalid_email" {
  command = plan

  variables {
    email_receivers = { bad = "not-an-email" }
  }

  expect_failures = [var.email_receivers]
}

run "rejects_bad_operator" {
  command = plan

  variables {
    metric_alerts = {
      bad = {
        scope_id         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Cache/redis/test"
        metric_namespace = "Microsoft.Cache/redis"
        metric_name      = "serverLoad"
        aggregation      = "Maximum"
        operator         = "Above"
        threshold        = 80
        description      = "Invalid operator."
      }
    }
  }

  expect_failures = [var.metric_alerts]
}
