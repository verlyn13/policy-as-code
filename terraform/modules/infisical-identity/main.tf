terraform {
  required_version = ">= 1.13.2"
  required_providers {
    infisical = {
      source  = "infisical/infisical"
      version = "~> 0.15.0"
    }
  }
}

resource "infisical_identity" "service" {
  name = "${var.service_name}-${var.environment}"
  role = var.identity_role
}

resource "infisical_identity_universal_auth" "auth" {
  identity_id = infisical_identity.service.id

  client_secret_ttl     = var.client_secret_ttl
  access_token_ttl      = var.access_token_ttl
  access_token_max_ttl  = var.access_token_max_ttl
  access_token_num_uses = var.access_token_num_uses

  access_token_trusted_ips = [for ip in var.trusted_ips : { ip_address = ip }]

  # NOTE: Do not output client_secret from this module to avoid leaking in state.
}

