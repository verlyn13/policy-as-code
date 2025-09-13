package kubernetes.admission

import data.lib.common
import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Metadata for policy documentation
# METADATA
# title: Kubernetes Pod Security Policy
# description: Enforces security best practices for Kubernetes pods
# authors:
# - Policy Team
# custom:
#   severity: high
#   category: security
#   version: 1.0.0

default allow := false

allow if {
	count(violation) == 0
}

policy := {
    "id": "kubernetes/pod-security",
    "title": "Kubernetes Pod Security Policy",
    "docs_url": "https://github.com/verlyn13/pac/blob/main/policies/kubernetes/pod-security.rego"
}

# Decision record for audit logging
decision := {
    "allowed": allow,
    "policy": policy,
    "violations": violation,
    "resource": common.resource_identifier(input),
    "timestamp": time.now_ns(),
}

violation contains msg if {
	container := input.spec.containers[_]
	not container.securityContext.runAsNonRoot
	msg := sprintf("Container '%s' must run as non-root user", [container.name])
}

violation contains msg if {
	container := input.spec.containers[_]
	container.securityContext.privileged
	msg := sprintf("Container '%s' must not run in privileged mode", [container.name])
}

violation contains msg if {
	container := input.spec.containers[_]
	container.securityContext.allowPrivilegeEscalation
	msg := sprintf("Container '%s' must not allow privilege escalation", [container.name])
}

violation contains msg if {
	container := input.spec.containers[_]
	not container.securityContext.readOnlyRootFilesystem
	msg := sprintf("Container '%s' should have a read-only root filesystem", [container.name])
}

violation contains msg if {
	container := input.spec.containers[_]
	not container.resources.limits.memory
	msg := sprintf("Container '%s' must specify memory limits", [container.name])
}

violation contains msg if {
	container := input.spec.containers[_]
	not container.resources.limits.cpu
	msg := sprintf("Container '%s' must specify CPU limits", [container.name])
}

violation contains msg if {
	container := input.spec.containers[_]
	not container.livenessProbe
	msg := sprintf("Container '%s' should have a liveness probe", [container.name])
}

violation contains msg if {
	container := input.spec.containers[_]
	not container.readinessProbe
	msg := sprintf("Container '%s' should have a readiness probe", [container.name])
}
