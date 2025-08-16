package kubernetes.admission

import future.keywords.contains
import future.keywords.if
import future.keywords.in

default allow := false

allow if {
    count(violation) == 0
}

violation[msg] {
    container := input.spec.containers[_]
    not container.securityContext.runAsNonRoot
    msg := sprintf("Container '%s' must run as non-root user", [container.name])
}

violation[msg] {
    container := input.spec.containers[_]
    container.securityContext.privileged
    msg := sprintf("Container '%s' must not run in privileged mode", [container.name])
}

violation[msg] {
    container := input.spec.containers[_]
    container.securityContext.allowPrivilegeEscalation
    msg := sprintf("Container '%s' must not allow privilege escalation", [container.name])
}

violation[msg] {
    container := input.spec.containers[_]
    not container.securityContext.readOnlyRootFilesystem
    msg := sprintf("Container '%s' should have a read-only root filesystem", [container.name])
}

violation[msg] {
    container := input.spec.containers[_]
    not container.resources.limits.memory
    msg := sprintf("Container '%s' must specify memory limits", [container.name])
}

violation[msg] {
    container := input.spec.containers[_]
    not container.resources.limits.cpu
    msg := sprintf("Container '%s' must specify CPU limits", [container.name])
}

violation[msg] {
    container := input.spec.containers[_]
    not container.livenessProbe
    msg := sprintf("Container '%s' should have a liveness probe", [container.name])
}

violation[msg] {
    container := input.spec.containers[_]
    not container.readinessProbe
    msg := sprintf("Container '%s' should have a readiness probe", [container.name])
}