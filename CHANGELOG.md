# Changelog

All notable changes to this project are documented here. Versions follow [Semantic Versioning](https://semver.org/).

## [3.0.0] - Terraform Registry release

### Breaking changes
- **The repository root is now a reusable module**, published as `OkiriGabriel/platform/azurerm`.
  The hub-and-spoke deployment that used to live at the root moved to `examples/complete/`. Run Terraform from
  that folder, and move any local state there first.
- The repository was renamed from `terraform-azure-platform` to `terraform-azurerm-platform` (GitHub redirects the old URL).
- `modules/ai-ml`: private endpoints now need `private_endpoints_enabled = true` as well as `private_endpoint_subnet_id`.
  An explicit flag works even when the subnet is created in the same apply.

### Added
- Root platform module:
  - always creates a resource group (or uses an existing one) and a Log Analytics workspace
  - opt-in `ai_ml`, `postgresql` and `alerts` features
  - adds a random suffix so global names stay unique
- `examples/basic`: a private PostgreSQL database with email alerts in a new VNet.
- Root module test suite, plus CI validation of both examples.
- `modules/postgresql`: private Flexible Server with a Key Vault-stored password, Entra auth, and optional HA and geo-backup.
- `modules/alerts`: action group, metric alerts and a Service Health alert.

### Changed
- azurerm provider `~> 4.81` with zero deprecation warnings. Key Vaults set `rbac_authorization_enabled`
  explicitly, which azurerm v5 requires.

### Fixed
- Two storage account names were over Azure's 24-character limit.

## [2.1.0]
- AI/ML module (Azure ML, OpenAI, AI Search), standardized module layout, CI module tests,
  free-by-default security settings.
