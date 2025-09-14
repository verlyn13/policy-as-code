package vercel.app

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# METADATA
# title: Vercel Project Configuration Policy
# description: Validates Vercel env var usage and secret handling norms
# authors:
# - Policy Team
# custom:
#   severity: high
#   category: platform
#   version: 1.0.0

default allow := false

allow if {
  count(deny) == 0
}

policy := {
  "id": "vercel/app",
  "title": "Vercel Project Configuration Policy",
  "docs_url": "https://github.com/verlyn13/pac/blob/main/policies/vercel/app.rego"
}

# Input shape expectation (example):
# input = {
#   "project": {"name": "journal"},
#   "env": {
#     "public": {"NEXT_PUBLIC_SUPABASE_URL": "..."},
#     "server": {"INFISICAL_*": "..."},
#     "secret": {}
#   }
# }

# 1) Public envs must be prefixed with NEXT_PUBLIC_
deny contains msg if {
  kv := input.env.public
  some k in object.keys(kv)
  not startswith(k, "NEXT_PUBLIC_")
  msg := sprintf("Public env must be NEXT_PUBLIC_*: %s", [k])
}

# 2) Disallow storing sensitive secrets in Vercel
sensitive_keys := {
  "JWT_PRIVATE_KEY",
  "SUPABASE_SERVICE_ROLE_KEY",
  "AES_KEY",
  "DATABASE_URL",
}

deny contains msg if {
  kv := input.env.public
  some k in object.keys(kv)
  k in sensitive_keys
  msg := sprintf("Sensitive key must not be public: %s", [k])
}

deny contains msg if {
  kv := input.env.server
  some k in object.keys(kv)
  k in sensitive_keys
  not startswith(k, "INFISICAL_")
  msg := sprintf("Do not store secret material in Vercel; fetch via Infisical: %s", [k])
}

# 3) Require Infisical boot vars to enable runtime fetch
required_infisical := {
  "INFISICAL_SERVER_URL",
  "INFISICAL_PROJECT_ID",
  "INFISICAL_ENVIRONMENT",
}

deny contains msg if {
  kv := input.env.server
  missing := required_infisical - object.keys(kv)
  count(missing) > 0
  msg := sprintf("Missing required Infisical boot vars: %v", [missing])
}

decision := {
  "allowed": allow,
  "policy": policy,
  "denials": deny,
  "timestamp": time.now_ns()
}
