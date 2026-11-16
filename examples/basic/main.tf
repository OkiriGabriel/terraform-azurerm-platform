# Basic example: a private PostgreSQL database with email alerts.
#
#   terraform init
#   terraform apply -var="alert_email=you@yourdomain.com"
#
# Cost: about $15-20/month (Burstable PostgreSQL, Log Analytics, a few alert rules).
# Remove everything with: terraform destroy

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.81"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {}
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "centralus"
}

variable "alert_email" {
  description = "Email address that receives alerts."
  type        = string
}

# A small VNet with a subnet for private endpoints.
resource "azurerm_resource_group" "network" {
  name     = "app-dev-network-rg"
  location = var.location
}

resource "azurerm_virtual_network" "main" {
  name                = "app-dev-vnet"
  resource_group_name = azurerm_resource_group.network.name
  location            = var.location
  address_space       = ["10.10.0.0/16"]
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "private-endpoints"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.10.1.0/24"]
}

module "platform" {
  # From the Terraform Registry:
  #   source  = "OkiriGabriel/platform/azurerm"
  #   version = "~> 3.0"
  source = "../../"

  name_prefix = "app-dev"
  location    = var.location
  tags        = { Environment = "dev" }

  network = {
    private_endpoint_subnet_id = azurerm_subnet.private_endpoints.id
    private_dns_vnet_ids       = { main = azurerm_virtual_network.main.id }
  }

  postgresql = {
    enabled   = true
    databases = ["app"]
  }

  alerts = {
    enabled         = true
    email_receivers = { owner = var.alert_email }
  }
}

output "postgresql_fqdn" {
  description = "Private FQDN of the PostgreSQL server."
  value       = module.platform.postgresql.fqdn
}

output "postgresql_password" {
  description = "Generated admin password (run: terraform output -raw postgresql_password)."
  value       = module.platform.postgresql_administrator_password
  sensitive   = true
}
