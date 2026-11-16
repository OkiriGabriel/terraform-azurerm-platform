# PostgreSQL Module

Deploys an **Azure Database for PostgreSQL Flexible Server**. It is private by default and low cost by default:

- Burstable `B_Standard_B1ms` SKU by default (about $15/month plus storage). Scales up to General Purpose or Memory Optimized.
- **Private endpoint** plus a `privatelink.postgres.database.azure.com` DNS zone linked to your VNets. Public access is off.
- Generated 32-character admin password, optionally stored in **Key Vault**.
- **Microsoft Entra ID** authentication alongside the password, with an optional Entra admin.
- Optional zone-redundant **high availability** and **geo-redundant backups**.
- Databases and server parameters defined as code.
- Diagnostic logs and metrics sent to Log Analytics.
- Guardrails that warn about high availability on Burstable SKUs, an unreachable server (no public access and no
  private endpoint), and a missing tenant ID.

## Usage

```hcl
module "postgresql" {
  source = "./modules/postgresql"

  name                = "example-dev-psql"
  resource_group_name = module.resource_group.name
  location            = module.resource_group.location
  tenant_id           = local.tenant_id
  databases           = ["app"]

  private_endpoint_subnet_id = module.spoke1.subnet_ids["WorkloadSubnet"]
  private_dns_zone_vnet_ids = {
    hub    = module.hub.vnet_id
    spoke1 = module.spoke1.vnet_id
  }

  store_password_in_key_vault = true
  key_vault_id                = module.key_vault.key_vault_id
  log_analytics_workspace_id  = azurerm_log_analytics_workspace.main.id
}
```

In this repository the module is wired up in [`database.tf`](../../examples/complete/database.tf). Configure it with `database_config` in
`examples/complete/vars_enviro_dev.tf` / `examples/complete/var_enviro_prod.tf`. It is **disabled by default** (`enabled = false`).

## Dev vs prod defaults in this repo

| Setting | Dev | Prod |
|---------|-----|------|
| SKU | `B_Standard_B1ms` (Burstable) | `GP_Standard_D2ds_v5` (General Purpose) |
| Storage | 32 GB | 128 GB |
| High availability | Off | `ZoneRedundant` |
| Geo-redundant backup | Off | On |
| Backup retention | 7 days | 35 days |

## Connecting

```bash
# Read the admin password from Key Vault
az keyvault secret show --vault-name example-dev-kvt --name example-dev-psql-admin-password --query value -o tsv

# From a VM or container inside the hub/spoke VNets (the FQDN resolves to the private IP)
psql "host=$(terraform output -raw postgresql_fqdn) port=5432 dbname=app user=psqladmin sslmode=require"
```

To sign in with Entra ID instead of the password, set `entra_administrator` and use an access token as the password:
`PGPASSWORD=$(az account get-access-token --resource-type oss-rdbms --query accessToken -o tsv)`.

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `name` | Globally unique server name | `string` | n/a |
| `resource_group_name` | Resource group | `string` | n/a |
| `location` | Azure region | `string` | n/a |
| `tags` | Tags for every resource | `map(string)` | `{}` |
| `postgresql_version` | 13, 14, 15, 16 or 17 | `string` | `"16"` |
| `sku_name` | `B_`, `GP_` or `MO_Standard_*` | `string` | `"B_Standard_B1ms"` |
| `storage_mb` | Storage size in MB | `number` | `32768` |
| `auto_grow_enabled` | Grow storage automatically | `bool` | `true` |
| `backup_retention_days` | 7-35 | `number` | `7` |
| `geo_redundant_backup_enabled` | Backups in paired region (set at creation) | `bool` | `false` |
| `high_availability_mode` | `null`, `SameZone`, `ZoneRedundant` | `string` | `null` |
| `zone` | Primary availability zone | `string` | `null` |
| `databases` | Databases to create | `list(string)` | `[]` |
| `server_configurations` | Server parameters | `map(string)` | `{}` |
| `administrator_login` | Admin user (reserved names rejected) | `string` | `"psqladmin"` |
| `entra_auth_enabled` | Enable Entra ID authentication | `bool` | `true` |
| `tenant_id` | Entra tenant (required with Entra auth) | `string` | `null` |
| `entra_administrator` | `{ object_id, principal_name, principal_type }` | `object` | `null` |
| `store_password_in_key_vault` | Write the admin password to Key Vault | `bool` | `false` |
| `key_vault_id` | Target Key Vault | `string` | `null` |
| `public_network_access_enabled` | Allow public access | `bool` | `false` |
| `firewall_rules` | Public firewall rules `{ start_ip_address, end_ip_address }` | `map(object)` | `{}` |
| `private_endpoint_enabled` | Create a private endpoint | `bool` | `true` |
| `private_endpoint_subnet_id` | Subnet for the private endpoint | `string` | `null` |
| `private_dns_zone_vnet_ids` | VNets to link to the private DNS zone | `map(string)` | `{}` |
| `diagnostics_enabled` | Send logs/metrics to Log Analytics | `bool` | `true` |
| `log_analytics_workspace_id` | Log Analytics workspace | `string` | `null` |

## Outputs

| Name | Description |
|------|-------------|
| `server_id` / `server_name` / `fqdn` | Server identifiers |
| `administrator_login` | Admin user name |
| `administrator_password` | Generated password (sensitive) |
| `administrator_password_secret_id` | Key Vault secret ID (null when not stored) |
| `database_names` | Databases created |
| `private_dns_zone_id` | Private DNS zone ID (null without private endpoint) |

## Notes

- The generated password is kept in Terraform state. Protect the state file, for example with a remote backend
  that has encryption and access control.
- `geo_redundant_backup_enabled` can't be changed after the server is created.

## Testing

```bash
cd modules/postgresql && terraform init -backend=false && terraform test
```
