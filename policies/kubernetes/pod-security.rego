package kubernetes.admission

import data.lib.common
import data.lib.errors
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
    base := sprintf("Container '%s' must run as non-root user", [container.name])
    msg := errors.format(policy, base)
}

violation contains msg if {
    container := input.spec.containers[_]
    container.securityContext.privileged
    base := sprintf("Container '%s' must not run in privileged mode", [container.name])
    msg := errors.format(policy, base)
}

violation contains msg if {
    container := input.spec.containers[_]
    container.securityContext.allowPrivilegeEscalation
    base := sprintf("Container '%s' must not allow privilege escalation", [container.name])
    msg := errors.format(policy, base)
}

violation contains msg if {
    container := input.spec.containers[_]
    not container.securityContext.readOnlyRootFilesystem
    base := sprintf("Container '%s' should have a read-only root filesystem", [container.name])
    msg := errors.format(policy, base)
}

violation contains msg if {
    container := input.spec.containers[_]
    not container.resources.limits.memory
    base := sprintf("Container '%s' must specify memory limits", [container.name])
    msg := errors.format(policy, base)
}

violation contains msg if {
    container := input.spec.containers[_]
    not container.resources.limits.cpu
    base := sprintf("Container '%s' must specify CPU limits", [container.name])
    msg := errors.format(policy, base)
}

violation contains msg if {
    container := input.spec.containers[_]
    not container.livenessProbe
    base := sprintf("Container '%s' should have a liveness probe", [container.name])
    msg := errors.format(policy, base)
}

violation contains msg if {
    container := input.spec.containers[_]
    not container.readinessProbe
    base := sprintf("Container '%s' should have a readiness probe", [container.name])
    msg := errors.format(policy, base)
}
