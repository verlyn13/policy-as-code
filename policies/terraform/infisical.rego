package terraform.infisical

import data.lib.errors
import future.keywords.contains
import future.keywords.if
import future.keywords.in

# METADATA
# title: Infisical Terraform Policy
# description: Enforce secure Infisical configuration (universal auth, approvals)
# authors:
# - Policy Team
# custom:
#   severity: high
#   category: security
#   version: 1.0.0

default allow := false

allow if {
  count(deny) == 0
}

policy := {
  "id": "terraform/infisical",
  "title": "Infisical Terraform Policy",
  "docs_url": "https://github.com/verlyn13/pac/blob/main/policies/terraform/infisical.rego"
}

deny contains msg if {
  r := input.resource_changes[_]
  r.type == "infisical_identity_universal_auth"
  after := r.change.after
  not after.client_secret_ttl
  msg := errors.format(policy, sprintf("Universal Auth must set client_secret_ttl", []))
}

deny contains msg if {
  r := input.resource_changes[_]
  r.type == "infisical_identity_universal_auth"
  after := r.change.after
  after.client_secret_ttl > 7200
  msg := errors.format(policy, sprintf("client_secret_ttl (%d) exceeds 7200 seconds", [after.client_secret_ttl]))
}

deny contains msg if {
  r := input.resource_changes[_]
  r.type == "infisical_identity_universal_auth"
  after := r.change.after
  after.access_token_ttl > 1800
  msg := errors.format(policy, sprintf("access_token_ttl (%d) exceeds 1800 seconds", [after.access_token_ttl]))
}

deny contains msg if {
  r := input.resource_changes[_]
  r.type == "infisical_identity_universal_auth"
  after := r.change.after
  after.access_token_max_ttl > 3600
  msg := errors.format(policy, sprintf("access_token_max_ttl (%d) exceeds 3600 seconds", [after.access_token_max_ttl]))
}

deny contains msg if {
  r := input.resource_changes[_]
  r.type == "infisical_identity_universal_auth"
  after := r.change.after
  after.access_token_num_uses > 100
  msg := errors.format(policy, sprintf("access_token_num_uses (%d) exceeds 100 uses", [after.access_token_num_uses]))
}

# For production workspaces, require IP allowlist
deny contains msg if {
  r := input.resource_changes[_]
  r.type == "infisical_identity_universal_auth"
  after := r.change.after
  lower(trim_space(after.environment)) == "prod"
  not after.access_token_trusted_ips
  msg := errors.format(policy, sprintf("prod environment requires access_token_trusted_ips allowlist", []))
}

# Approval policy: require at least two groups for production changes
deny contains msg if {
  r := input.resource_changes[_]
  r.type == "infisical_approval_policy"
  after := r.change.after
  lower(trim_space(after.environment)) == "prod"
  count(after.approver_group_ids) < 2
  msg := errors.format(policy, sprintf("prod approval policy requires at least two approver groups", []))
}

# Decision record
decision := {
  "allowed": allow,
  "policy": policy,
  "denials": deny,
  "resource_count": count(input.resource_changes),
  "timestamp": time.now_ns()
}

