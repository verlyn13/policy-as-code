package infisical.intent

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Validate intent loaded under data.infisical.journal

default allow := false

allow if {
  count(deny) == 0
}

# Convenience references
project := data.infisical.journal
identities := data.infisical.journal.identities

# Canonical path sets
canonical_write_prefixes := {"/auth/jwt/", "/auth/aes/"}
canonical_read_prefixes := {"/auth/jwt/", "/auth/aes/", "/auth/oauth/"}
public_jwks := "/auth/jwt/public_jwks"

# Helpers
is_canonical_write(wp) if {
  some pref in canonical_write_prefixes
  startswith(wp, pref)
}

is_canonical_read(rp) if {
  rp == public_jwks
} else if {
  some pref in canonical_read_prefixes
  startswith(rp, pref)
}

# Deny: Only rotator may write in prod and only to canonical paths
deny contains msg if {
  id := identities[_]
  id.env == "prod"
  some p
  wp := id.permissions.write_paths[p]
  not is_canonical_write(wp)
  msg := sprintf("Non-canonical prod write path for %s: %s", [id.name, wp])
}

deny contains msg if {
  id := identities[_]
  id.env == "prod"
  count(id.permissions.write_paths) > 0
  id.name != "rotator@ops-prod"
  msg := sprintf("Only rotator@ops-prod may write in prod; found %s", [id.name])
}

# Deny: Any write path outside canonical set (all envs)
deny contains msg if {
  id := identities[_]
  some p
  wp := id.permissions.write_paths[p]
  not is_canonical_write(wp)
  msg := sprintf("Non-canonical write path for %s: %s", [id.name, wp])
}

# Deny: Read paths must be canonical set or public_jwks
deny contains msg if {
  id := identities[_]
  some p
  rp := id.permissions.read_paths[p]
  not is_canonical_read(rp)
  msg := sprintf("Non-canonical read path for %s: %s", [id.name, rp])
}

# Deny: Missing environment or invalid project role
valid_roles := {"runtime", "ci", "security-ops-prj"}

deny contains msg if {
  id := identities[_]
  not id.env
  msg := sprintf("Identity %s missing environment", [id.name])
}

deny contains msg if {
  id := identities[_]
  not id.project_role in valid_roles
  msg := sprintf("Identity %s has invalid project role: %v", [id.name, id.project_role])
}

# Warn: runtime/ci missing public JWKS read path
warn contains msg if {
  id := identities[_]
  id.project_role in {"runtime", "ci"}
  not public_jwks in id.permissions.read_paths
  msg := sprintf("%s missing read path %s", [id.name, public_jwks])
}

# Deny: Auth-method constraints and TTL bounds
# - runtime must not enable token auth
deny contains msg if {
  id := identities[_]
  id.project_role == "runtime"
  id.auth.token_auth.enabled
  msg := sprintf("Token Auth not allowed for runtime: %s", [id.name])
}

# - rotator must not enable token auth
deny contains msg if {
  id := identities[_]
  startswith(id.name, "rotator@ops-")
  id.auth.token_auth.enabled
  msg := sprintf("Token Auth not allowed for rotator: %s", [id.name])
}

# UA TTL upper bounds
deny contains msg if {
  id := identities[_]
  ua := id.auth.universal_auth
  ua.enabled
  contains(id.name, "rotator@ops-")
  ua.access_token_ttl_seconds > 1200
  msg := sprintf("UA TTL > 1200s for %s", [id.name])
}

deny contains msg if {
  id := identities[_]
  ua := id.auth.universal_auth
  ua.enabled
  not contains(id.name, "rotator@ops-")
  ua.access_token_ttl_seconds > 3600
  msg := sprintf("UA TTL > 3600s for %s", [id.name])
}

deny contains msg if {
  id := identities[_]
  oidc := id.auth.oidc
  oidc.enabled
  oidc.access_token_ttl_seconds > 1800
  msg := sprintf("OIDC TTL > 1800s for %s", [id.name])
}

deny contains msg if {
  id := identities[_]
  tok := id.auth.token_auth
  tok.enabled
  tok.access_token_ttl_seconds > 1800
  msg := sprintf("Token Auth TTL > 1800s for %s", [id.name])
}

# Token Auth fallback allowed only for CI identities
deny contains msg if {
  id := identities[_]
  tok := id.auth.token_auth
  tok.enabled
  not startswith(id.name, "ci@github-")
  msg := sprintf("Token Auth fallback only allowed for CI identities: %s", [id.name])
}

deny contains msg if {
  id := identities[_]
  tok := id.auth.token_auth
  tok.enabled
  tok.access_token_max_ttl_seconds > 1800
  msg := sprintf("Token Auth max TTL > 1800s for %s", [id.name])
}

# CI OIDC strictness (prod): issuer & subjects & audiences
deny contains msg if {
  id := identities[_]
  id.name == "ci@github-prod"
  oidc := id.auth.oidc
  not oidc.enabled
  msg := "ci@github-prod must enable OIDC"
}

deny contains msg if {
  id := identities[_]
  id.name == "ci@github-prod"
  oidc := id.auth.oidc
  oidc.enabled
  oidc.issuer != "https://token.actions.githubusercontent.com"
  msg := "ci@github-prod OIDC issuer must be https://token.actions.githubusercontent.com"
}

deny contains msg if {
  id := identities[_]
  id.name == "ci@github-prod"
  oidc := id.auth.oidc
  oidc.enabled
  count(oidc.subjects) == 0
  msg := "ci@github-prod OIDC subjects must include repo:<owner>/<repo>:..."
}

deny contains msg if {
  id := identities[_]
  id.name == "ci@github-prod"
  oidc := id.auth.oidc
  oidc.enabled
  count([s | s := oidc.subjects[_]; startswith(s, "repo:")]) == 0
  msg := "ci@github-prod OIDC subjects must include repo:<owner>/<repo>:..."
}

deny contains msg if {
  id := identities[_]
  id.name == "ci@github-prod"
  oidc := id.auth.oidc
  oidc.enabled
  count(oidc.audiences) == 0
  msg := "ci@github-prod OIDC audiences must not be empty"
}

# Warn: Prod IP allowlist must not be 0.0.0.0/0 (temporary bootstrap allowed)
warn contains msg if {
  id := identities[_]
  id.env == "prod"
  ua := id.auth.universal_auth
  ua.enabled
  ips := ua.client_secret_trusted_ips
  some i
  ips[i] == "0.0.0.0/0"
  msg := sprintf("Bootstrap IP allowlist is broad for %s; tighten before prod cutover", [id.name])
}

decision := {
  "allowed": allow,
  "denials": deny,
  "warnings": [m | warn[m]],
  "timestamp": time.now_ns()
}
