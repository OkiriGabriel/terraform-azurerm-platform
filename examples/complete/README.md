# Complete Example: Full Hub-and-Spoke Platform

This folder contains the full platform deployment. Before v3.0.0 it lived at the repository root. It deploys:

- a hub-and-spoke network
- Container Apps, ACR, Key Vaults, Redis and Blob Storage
- optional AI/ML, PostgreSQL and alerts

Each feature is configured per environment with Terraform workspaces.

| File | Purpose |
|------|---------|
| `provider.tf` | Terraform and provider versions, backend |
| `locals.tf` | Picks the environment from the workspace name |
| `vars_enviro_dev.tf` / `var_enviro_prod.tf` | Per-environment settings (`local.dev` / `local.prod`) |
| `ai_ml.tf`, `database.tf`, `alerts.tf` | Optional features, toggled with `*_config.enabled` |
| `tests/root_plan.tftest.hcl` | Plan smoke test with mocked providers |

## Usage

```bash
cd examples/complete
az login
terraform init
terraform workspace select example-infrastructure-dev   # or: terraform workspace new ...
terraform plan -out=tfplan
terraform apply tfplan
```

Before you deploy, edit the subscription and tenant IDs in `vars_enviro_dev.tf` / `var_enviro_prod.tf`.

> **Migrating from v2.x:** run Terraform from this folder instead of the repository root. If you have local state
> (`terraform.tfstate` or `terraform.tfstate.d/`) at the repository root, move it here first. Remote backends need no
> change.

## Testing

```bash
terraform init -backend=false && terraform test
```
