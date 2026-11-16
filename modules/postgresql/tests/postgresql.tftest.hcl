# Unit tests for the postgresql module. Run with: terraform test
# Uses mocked providers, so no Azure credentials are required.

mock_provider "azurerm" {
  mock_resource "azurerm_postgresql_flexible_server" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.DBforPostgreSQL/flexibleServers/test-psql"
    }
  }
  mock_resource "azurerm_private_dns_zone" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/privateDnsZones/privatelink.postgres.database.azure.com"
    }
  }
}

mock_provider "random" {}

variables {
  name                       = "test-psql"
  resource_group_name        = "rg-test"
  location                   = "centralus"
  tenant_id                  = "00000000-0000-0000-0000-000000000000"
  private_endpoint_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet/subnets/workload"
  log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/test-law"
}

run "secure_low_cost_defaults" {
  command = plan

  assert {
    condition     = azurerm_postgresql_flexible_server.this.sku_name == "B_Standard_B1ms"
    error_message = "Default SKU should be the cheapest Burstable tier."
  }

  assert {
    condition     = azurerm_postgresql_flexible_server.this.public_network_access_enabled == false
    error_message = "Public network access must be disabled by default."
  }

  assert {
    condition     = length(azurerm_postgresql_flexible_server.this.high_availability) == 0
    error_message = "High availability should be off by default."
  }

  assert {
    condition     = length(azurerm_private_endpoint.this) == 1 && length(azurerm_private_dns_zone.this) == 1
    error_message = "A private endpoint and private DNS zone should be created by default."
  }

  assert {
    condition     = length(azurerm_postgresql_flexible_server_firewall_rule.this) == 0
    error_message = "No firewall rules should exist while public access is disabled."
  }
}

run "production_shape" {
  command = plan

  variables {
    sku_name                     = "GP_Standard_D2ds_v5"
    high_availability_mode       = "ZoneRedundant"
    geo_redundant_backup_enabled = true
    backup_retention_days        = 35
    databases                    = ["app", "analytics"]
    server_configurations        = { log_min_duration_statement = "500" }
    private_dns_zone_vnet_ids = {
      hub    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/hub"
      spoke1 = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/spoke1"
    }
  }

  assert {
    condition     = azurerm_postgresql_flexible_server.this.high_availability[0].mode == "ZoneRedundant"
    error_message = "High availability mode should be applied."
  }

  assert {
    condition     = length(azurerm_postgresql_flexible_server_database.this) == 2
    error_message = "Both databases should be created."
  }

  assert {
    condition     = length(azurerm_private_dns_zone_virtual_network_link.this) == 2
    error_message = "Each VNet should be linked to the private DNS zone."
  }
}

run "public_access_with_firewall" {
  command = plan

  variables {
    public_network_access_enabled = true
    private_endpoint_enabled      = false
    firewall_rules = {
      office = { start_ip_address = "203.0.113.10", end_ip_address = "203.0.113.10" }
    }
  }

  assert {
    condition     = length(azurerm_postgresql_flexible_server_firewall_rule.this) == 1
    error_message = "Firewall rules should be created when public access is enabled."
  }

  assert {
    condition     = length(azurerm_private_endpoint.this) == 0
    error_message = "No private endpoint should be created when disabled."
  }
}

run "password_stored_in_key_vault" {
  command = plan

  variables {
    store_password_in_key_vault = true
    key_vault_id                = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.KeyVault/vaults/test-kv"
  }

  assert {
    condition     = azurerm_key_vault_secret.admin_password[0].name == "test-psql-admin-password"
    error_message = "The admin password should be stored in Key Vault."
  }
}

run "rejects_ha_on_burstable" {
  command = plan

  variables {
    high_availability_mode = "SameZone"
  }

  expect_failures = [check.configuration]
}

run "rejects_reserved_admin_name" {
  command = plan

  variables {
    administrator_login = "admin"
  }

  expect_failures = [var.administrator_login]
}
