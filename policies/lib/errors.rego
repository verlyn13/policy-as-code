package lib.errors

import future.keywords.if

# Format a standardized denial message that references the policy.
format(policy, message) := out if {
  id := policy.id
  title := policy.title
  url := policy.docs_url
  out := sprintf("Denied by policy '%s' — %s. %s See %s", [id, title, message, url])
}

# Return a structured error object for decision logs or APIs.
object(policy, message, remediation) := err if {
  err := {
    "policy": policy,
    "message": message,
    "remediation": remediation,
    "timestamp": time.now_ns(),
  }
}

