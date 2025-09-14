output "identity_id" {
  value = infisical_identity.service.id
}

output "client_id" {
  value = infisical_identity_universal_auth.auth.client_id
}

# Intentionally NOT outputting client_secret to avoid leaking secret material into state.

