package infisical.intent_test

import data.infisical.intent
import future.keywords.if

test_journal_intents_allow if {
  # Mock data.infisical.journal for test to avoid relying on external data dirs
  journal := {
    "project": {
      "meta": {"project": {"name": "journal"}}
    },
    "identities": [
      {"name": "rotator@ops-prod", "env": "prod", "project_role": "security-ops-prj",
        "auth": {"universal_auth": {"enabled": true, "access_token_ttl_seconds": 1200, "client_secret_trusted_ips": ["1.2.3.4/32"]}},
        "permissions": {"read_paths": ["/auth/jwt/*"], "write_paths": ["/auth/jwt/*"]}
      },
      {"name": "token-service@journal-prod", "env": "prod", "project_role": "runtime",
        "auth": {"universal_auth": {"enabled": true, "access_token_ttl_seconds": 3600, "client_secret_trusted_ips": ["0.0.0.0/0"]}},
        "permissions": {"read_paths": ["/auth/jwt/*"], "write_paths": []}
      },
      {"name": "ci@github-prod", "env": "prod", "project_role": "ci",
        "auth": {"oidc": {"enabled": true, "access_token_ttl_seconds": 1800, "issuer": "https://token.actions.githubusercontent.com", "subjects": ["repo:owner/repo:ref:refs/heads/main"], "audiences": ["api://Infisical"]}, "token_auth": {"enabled": true, "access_token_ttl_seconds": 1800}},
        "permissions": {"read_paths": ["/auth/jwt/public_jwks"], "write_paths": []}
      }
    ]
  }

  allow := intent.allow with data.infisical.journal as journal
  allow
}
