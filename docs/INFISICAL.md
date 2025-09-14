# Infisical Management via Policy as Code

This guide defines how we manage Infisical org and project configuration using Terraform and enforce standards with OPA.

## Goals
- Secure-by-default identities (Universal Auth) with tight TTLs and IP allowlists.
- Mandatory approval policies for production changes.
- Standard project structure and placeholders without leaking values.
- No secrets in Terraform state (use `ephemeral` blocks only).

## Terraform Modules

- `modules/infisical-identity`
  - Provisions `infisical_identity` + `infisical_identity_universal_auth` with safe defaults.
  - Outputs `identity_id` and `client_id` only (no `client_secret`).

- `modules/infisical-approval-policy`
  - Creates approval policies per environment; supports optional webhook.

- `modules/infisical-project-structure`
  - Creates standardized folders per environment.
  - Optionally creates placeholder secrets (values ignored by lifecycle).

### Example Usage (dev)

```hcl
module "service_identity" {
  source                 = "../../modules/infisical-identity"
  service_name           = "payments"
  environment            = "dev"
  identity_role          = "machine"
  client_secret_ttl      = 3600
  access_token_ttl       = 900
  access_token_max_ttl   = 3600
  access_token_num_uses  = 50
  trusted_ips            = ["10.0.0.0/8"]
}

module "prod_approval" {
  source              = "../../modules/infisical-approval-policy"
  name                = "prod-changes"
  environment         = "prod"
  approver_group_ids  = [var.platform_admins_group_id, var.security_auditors_group_id]
  webhook_url         = var.slack_webhook_url
}

module "project_structure" {
  source               = "../../modules/infisical-project-structure"
  app_slug             = "payments-api"
  environments         = ["dev", "stg", "prod"]
  placeholder_secrets  = ["DB_HOST", "DB_USER", "DB_PASSWORD"]
}
```

## Provider Auth

Use Universal Auth in `providers.tf` and supply credentials via environment variables or CI secrets:

```hcl
provider "infisical" {
  host = var.infisical_host
  auth {
    universal {
      client_id     = var.infisical_client_id
      client_secret = var.infisical_client_secret
    }
  }
}
```

## Enforcement (OPA)

- `policies/terraform/infisical.rego` enforces:
  - Universal Auth TTLs/uses within bounds
  - IP allowlists required for `prod`
  - `prod` approval policies require ≥ 2 groups

Run locally:
```bash
opa test policies/ tests/ -v
```

## Secret Handling

- Use Terraform `ephemeral "infisical_secret"` blocks exclusively. Our pre-commit hook `scripts/check-ephemeral.sh` fails on `data "infisical_secret"` usage.
- Never output `client_secret` from modules; retrieve at runtime via Infisical.

## Observability

- Decisions are logged and signed (see `docs/AUDIT.md`).
- CI enforces policy tests and coverage.

