# Unit tests for the root platform module. Run with: terraform init -backend=false && terraform test
# Uses mocked providers, so no Azure credentials are required.

mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id       = "22222222-2222-2222-2222-222222222222"
      subscription_id = "33333333-3333-3333-3333-333333333333"
      object_id       = "11111111-1111-1111-1111-111111111111"
    }
  }
  mock_data "azurerm_resource_group" {
    defaults = {
      id       = "/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/existing-rg"
      location = "centralus"
    }
  }
  mock_resource "azurerm_resource_group" {
    defaults = {
      id = "/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/app-dev-rg"
    }
  }
  mock_resource "azurerm_log_analytics_workspace" {
    defaults = {
      id = "/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/app-dev-rg/providers/Microsoft.OperationalInsights/workspaces/app-dev-law"
    }
  }
  mock_resource "azurerm_postgresql_flexible_server" {
    defaults = {
      id = "/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/app-dev-rg/providers/Microsoft.DBforPostgreSQL/flexibleServers/app-dev-psql"
    }
  }
  mock_resource "azurerm_private_dns_zone" {
    defaults = {
      id = "/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/app-dev-rg/providers/Microsoft.Network/privateDnsZones/privatelink.postgres.database.azure.com"
    }
  }
  mock_resource "azurerm_monitor_action_group" {
    defaults = {
      id = "/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/app-dev-rg/providers/Microsoft.Insights/actionGroups/app-dev-ag"
    }
  }
  mock_resource "azurerm_machine_learning_workspace" {
    defaults = {
      id = "/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/app-dev-rg/providers/Microsoft.MachineLearningServices/workspaces/app-dev-mlw"
    }
  }
  mock_resource "azurerm_cognitive_account" {
    defaults = {
      id = "/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/app-dev-rg/providers/Microsoft.CognitiveServices/accounts/app-dev-oai"
    }
  }
  mock_resource "azurerm_search_service" {
    defaults = {
      id = "/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/app-dev-rg/providers/Microsoft.Search/searchServices/app-dev-srch"
    }
  }
  mock_resource "azurerm_key_vault" {
    defaults = {
      id = "/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/app-dev-rg/providers/Microsoft.KeyVault/vaults/app-dev-mlkv"
    }
  }
  mock_resource "azurerm_storage_account" {
    defaults = {
      id = "/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/app-dev-rg/providers/Microsoft.Storage/storageAccounts/appdevmlsa"
    }
  }
  mock_resource "azurerm_application_insights" {
    defaults = {
      id = "/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/app-dev-rg/providers/Microsoft.Insights/components/app-dev-appi"
    }
  }
}

mock_provider "random" {}

variables {
  name_prefix = "app-dev"
  name_suffix = "t001"
  location    = "centralus"
}

run "foundation_only_by_default" {
  command = plan

  assert {
    condition     = azurerm_resource_group.this[0].name == "app-dev-rg"
    error_message = "Resource group should default to <name_prefix>-rg."
  }

  assert {
    condition     = azurerm_log_analytics_workspace.this.name == "app-dev-t001-law"
    error_message = "Log Analytics name should include the suffix."
  }

  assert {
    condition     = length(module.ai_ml) == 0 && length(module.postgresql) == 0 && length(module.alerts) == 0
    error_message = "All optional features must be off by default."
  }

  assert {
    condition     = output.ai_ml == null && output.postgresql == null
    error_message = "Feature outputs should be null when disabled."
  }
}

run "all_features_enabled" {
  command = plan

  variables {
    network = {
      private_endpoint_subnet_id = "/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/net-rg/providers/Microsoft.Network/virtualNetworks/vnet/subnets/pe"
      private_dns_vnet_ids       = { main = "/subscriptions/33333333-3333-3333-3333-333333333333/resourceGroups/net-rg/providers/Microsoft.Network/virtualNetworks/vnet" }
    }
    ai_ml = {
      enabled                   = true
      private_endpoints_enabled = true
      openai_deployments = {
        gpt-4o-mini = { model_name = "gpt-4o-mini", model_version = "2024-07-18", sku_name = "GlobalStandard" }
      }
    }
    postgresql = {
      enabled = true
    }
    alerts = {
      enabled         = true
      email_receivers = { devops = "devops@example.com" }
    }
  }

  assert {
    condition     = length(module.ai_ml) == 1 && length(module.postgresql) == 1 && length(module.alerts) == 1
    error_message = "All features should be planned when enabled."
  }

  assert {
    condition     = length(module.alerts[0].metric_alert_ids) == 5
    error_message = "Expected 4 PostgreSQL alerts and 1 OpenAI throttling alert."
  }
}

run "existing_resource_group" {
  command = plan

  variables {
    create_resource_group = false
    resource_group_name   = "existing-rg"
  }

  assert {
    condition     = length(azurerm_resource_group.this) == 0
    error_message = "No resource group should be created when using an existing one."
  }

  assert {
    condition     = azurerm_log_analytics_workspace.this.resource_group_name == "existing-rg"
    error_message = "Resources should deploy into the existing resource group."
  }
}

run "random_suffix_when_not_set" {
  command = plan

  variables {
    name_suffix = null
  }

  assert {
    condition     = length(random_string.suffix) == 1
    error_message = "A random suffix should be generated when name_suffix is null."
  }
}

run "rejects_long_prefix" {
  command = plan

  variables {
    name_prefix = "this-prefix-is-far-too-long"
  }

  expect_failures = [var.name_prefix]
}
