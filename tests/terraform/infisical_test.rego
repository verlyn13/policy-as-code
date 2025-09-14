package terraform.infisical_test

import data.terraform.infisical
import future.keywords.if

good_plan := {
  "resource_changes": [
    {
      "address": "infisical_identity_universal_auth.service_auth",
      "type": "infisical_identity_universal_auth",
      "change": {
        "actions": ["create"],
        "after": {
          "client_secret_ttl": 3600,
          "access_token_ttl": 900,
          "access_token_max_ttl": 3600,
          "access_token_num_uses": 50,
          "environment": "stg",
          "access_token_trusted_ips": [
            {"ip_address": "10.0.0.0/8"}
          ]
        }
      }
    },
    {
      "address": "infisical_approval_policy.stg_changes",
      "type": "infisical_approval_policy",
      "change": {
        "actions": ["create"],
        "after": {
          "environment": "stg",
          "approver_group_ids": ["grp-1"]
        }
      }
    }
  ]
}

bad_plan := {
  "resource_changes": [
    {
      "address": "infisical_identity_universal_auth.service_auth",
      "type": "infisical_identity_universal_auth",
      "change": {
        "actions": ["create"],
        "after": {
          "client_secret_ttl": 10800,
          "access_token_ttl": 2000,
          "access_token_max_ttl": 7200,
          "access_token_num_uses": 1000,
          "environment": "prod"
        }
      }
    },
    {
      "address": "infisical_approval_policy.prod_changes",
      "type": "infisical_approval_policy",
      "change": {
        "actions": ["create"],
        "after": {
          "environment": "prod",
          "approver_group_ids": ["grp-1"]
        }
      }
    }
  ]
}

test_allow_secure_infisical_config if {
  infisical.allow with input as good_plan
}

test_deny_insecure_infisical_config if {
  not infisical.allow with input as bad_plan
  denials := infisical.deny with input as bad_plan
  count(denials) >= 3
}
