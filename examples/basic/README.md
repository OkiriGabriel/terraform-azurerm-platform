# Basic Example

Deploys a private **PostgreSQL** database with **email alerts** by using the platform module:

- a resource group and Log Analytics workspace (from the module)
- a small VNet and a subnet for private endpoints
- a PostgreSQL Flexible Server (Burstable `B_Standard_B1ms`), reachable only through its private endpoint
- an action group plus PostgreSQL CPU, memory, storage and availability alerts, and a Service Health alert

```bash
az login
terraform init
terraform apply -var="alert_email=you@yourdomain.com"
terraform output -raw postgresql_password
```

**Cost:** about $15–20/month. Run `terraform destroy` when you're done.

To use the published module instead of the local path, replace `source = "../../"` with:

```hcl
source  = "OkiriGabriel/platform/azurerm"
version = "~> 3.0"
```
