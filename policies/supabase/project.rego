package supabase.project

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# METADATA
# title: Supabase Project Configuration Policy
# description: Validates secure Supabase settings and key handling
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
  "id": "supabase/project",
  "title": "Supabase Project Configuration Policy",
  "docs_url": "https://github.com/verlyn13/pac/blob/main/policies/supabase/project.rego"
}

# Input shape expectation (example):
# input = {
#   "api": {"jwt_secret": "***", "jwt_exp": 3600},
#   "keys": {"anon": "...", "service_role": "..."},
#   "auth": {"email_confirm": true},
#   "database": {"rls_required": true},
#   "exposure": {"public_env": ["NEXT_PUBLIC_SUPABASE_URL", "NEXT_PUBLIC_SUPABASE_ANON_KEY"]}
# }

# 1) Do not expose service role key via public env
deny contains msg if {
  pub := input.exposure.public_env
  some i
  pub[i] == "SUPABASE_SERVICE_ROLE_KEY"
  msg := "Service role key must never be public"
}

# 2) JWT secret presence and reasonable token lifetime
deny contains msg if {
  not input.api.jwt_secret
  msg := "JWT secret must be configured"
}

deny contains msg if {
  input.api.jwt_exp > 86400
  msg := "JWT expiration too long (>24h)"
}

# 3) RLS required for tables (boolean gate from config pipeline)
deny contains msg if {
  not input.database.rls_required
  msg := "RLS must be enforced on all application tables"
}

decision := {
  "allowed": allow,
  "policy": policy,
  "denials": deny,
  "timestamp": time.now_ns()
}

