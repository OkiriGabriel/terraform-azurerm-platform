# Smoke test: plans the whole root configuration with mocked providers (no Azure credentials).
# Catches wiring mistakes, type errors and invalid names before `terraform apply`.
# Run with: terraform init -backend=false && terraform test

mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      object_id       = "11111111-1111-1111-1111-111111111111"
      tenant_id       = "22222222-2222-2222-2222-222222222222"
      subscription_id = "33333333-3333-3333-3333-333333333333"
    }
  }
}

mock_provider "random" {}

run "dev_plan_defaults" {
  command = plan

  assert {
    condition     = module.resource_group.name == "example-dev-resource-group"
    error_message = "The default workspace should resolve to the dev environment."
  }

  assert {
    condition     = length(module.ai_ml) == 0 && length(module.postgresql) == 0 && length(module.alerts) == 0
    error_message = "Optional features (AI/ML, PostgreSQL, alerts) must be off by default to avoid cost."
  }

  assert {
    condition     = contains(keys(local.metric_alerts), "redis-server-load") && !contains(keys(local.metric_alerts), "postgresql-down")
    error_message = "Alert set should include always-on services and skip disabled ones."
  }
}
