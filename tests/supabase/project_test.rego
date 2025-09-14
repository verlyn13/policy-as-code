package supabase.project_test

import data.supabase.project
import future.keywords.if

good := {
  "api": {"jwt_secret": "***", "jwt_exp": 3600},
  "keys": {"anon": "anon", "service_role": "svc"},
  "auth": {"email_confirm": true},
  "database": {"rls_required": true},
  "exposure": {"public_env": ["NEXT_PUBLIC_SUPABASE_URL", "NEXT_PUBLIC_SUPABASE_ANON_KEY"]}
}

bad := {
  "api": {"jwt_exp": 172800},
  "keys": {"anon": "anon", "service_role": "svc"},
  "auth": {"email_confirm": false},
  "database": {"rls_required": false},
  "exposure": {"public_env": ["NEXT_PUBLIC_SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY"]}
}

test_allow_good_supabase_config if {
  project.allow with input as good
}

test_deny_bad_supabase_config if {
  not project.allow with input as bad
  denials := project.deny with input as bad
  count(denials) >= 3
}
