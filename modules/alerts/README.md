# Alerts Module

Email (and optional webhook) alerting on top of Azure Monitor:

- **Action group**: who gets notified (email addresses, plus Teams/Slack webhooks if you want them).
- **Metric alerts**: a map of rules. Each one watches a single metric on a single resource, and can filter by dimension.
- **Service Health alert**: Azure outages, planned maintenance and security advisories that affect your
  subscription. Free.
- A guardrail that warns when no receivers are configured, which would mean alerts that nobody sees.

**Cost:** about $0.10 per metric alert rule per month. Email notifications and Service Health alerts are free.

## Usage

```hcl
module "alerts" {
  source = "./modules/alerts"

  name_prefix         = "example-dev"
  resource_group_name = module.resource_group.name
  subscription_id     = local.subscription_id
  email_receivers     = { devops = "devops@example.com" }

  metric_alerts = {
    redis-server-load = {
      scope_id         = module.redis.redis_id["main"]
      metric_namespace = "Microsoft.Cache/redis"
      metric_name      = "serverLoad"
      aggregation      = "Maximum"
      operator         = "GreaterThan"
      threshold        = 80
      description      = "Redis server load is above 80%."
    }
  }
}
```

## Alerts configured in this repository

[`alerts.tf`](../../examples/complete/alerts.tf) builds the alert set automatically from what is deployed. Alerts for features that are
switched off (database, AI/ML) are left out.

| Alert | Resource | Condition | Severity |
|-------|----------|-----------|----------|
| `redis-server-load` | Redis | Server load > 80% | Warning |
| `redis-memory` | Redis | Memory used > 85% | Warning |
| `keyvault-availability` | Platform Key Vault | Availability < 99% | Error |
| `secrets-vault-availability` | App secrets Key Vault | Availability < 99% | Error |
| `backend-restarts` / `frontend-restarts` | Container Apps | > 3 restarts in 15 min | Warning |
| `postgresql-down` | PostgreSQL | Server not alive | Critical |
| `postgresql-cpu` / `postgresql-memory` | PostgreSQL | CPU > 80% / memory > 90% | Warning |
| `postgresql-storage` | PostgreSQL | Storage > 85% | Error |
| `openai-throttling` | Azure OpenAI | > 10 HTTP 429 responses in 15 min | Warning |
| Service Health | Subscription | Incident, maintenance, security, action required | n/a |

### Enable it

In `examples/complete/vars_enviro_dev.tf` (or `examples/complete/var_enviro_prod.tf`):

```hcl
alert_config = {
  enabled = true
  email_receivers = {
    devops = "you@yourdomain.com"
  }
  service_health_enabled   = true
  service_health_locations = []
}
```

Azure sends each address a confirmation email when it's added to the action group.

## Inputs

| Name | Description | Type | Default |
|------|-------------|------|---------|
| `name_prefix` | Prefix for resource names | `string` | n/a |
| `resource_group_name` | Resource group | `string` | n/a |
| `tags` | Tags | `map(string)` | `{}` |
| `action_group_short_name` | Name shown in notifications (≤ 12 chars) | `string` | `"infra-alert"` |
| `email_receivers` | `{ name = "email" }` | `map(string)` | `{}` |
| `webhook_receivers` | `{ name = "https://..." }` (sensitive) | `map(string)` | `{}` |
| `metric_alerts` | Map of `{ scope_id, metric_namespace, metric_name, aggregation, operator, threshold, description, severity, frequency, window_size, dimensions }` | `map(object)` | `{}` |
| `service_health_enabled` | Create the Service Health alert | `bool` | `true` |
| `subscription_id` | Subscription for Service Health | `string` | `null` |
| `service_health_locations` | Regions to watch (empty = all) | `list(string)` | `[]` |

## Outputs

| Name | Description |
|------|-------------|
| `action_group_id` | Action group ID. Reuse it for extra alert rules |
| `metric_alert_ids` | Map of alert key → rule ID |
| `service_health_alert_id` | Service Health alert ID (null when disabled) |

## Testing

```bash
cd modules/alerts && terraform init -backend=false && terraform test
```
