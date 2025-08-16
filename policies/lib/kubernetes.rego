package lib.kubernetes

import data.lib.common
import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Kubernetes-specific utility functions

# Check if pod is in system namespace
is_system_namespace(namespace) if {
    system_namespaces := {
        "kube-system",
        "kube-public",
        "kube-node-lease",
        "default"
    }
    namespace in system_namespaces
}

# Get container images from pod spec
container_images(pod) = images if {
    images := [img |
        container := pod.spec.containers[_]
        img := container.image
    ]
}

# Check if container has security context
has_security_context(container) if {
    container.securityContext
}

# Validate container security settings
secure_container(container) if {
    sc := container.securityContext
    sc.runAsNonRoot == true
    sc.privileged == false
    sc.allowPrivilegeEscalation == false
    sc.readOnlyRootFilesystem == true
    not sc.capabilities.add
}

# Check resource requirements
has_resource_limits(container) if {
    container.resources.limits.memory
    container.resources.limits.cpu
}

has_resource_requests(container) if {
    container.resources.requests.memory
    container.resources.requests.cpu
}

# Validate health checks
has_health_checks(container) if {
    container.livenessProbe
    container.readinessProbe
}

# Check if using latest tag
uses_latest_tag(image) if {
    endswith(image, ":latest")
} else if {
    not contains(image, ":")
}

# Extract registry from image
image_registry(image) = registry if {
    parts := split(image, "/")
    count(parts) > 1
    contains(parts[0], ".")
    registry := parts[0]
} else = "docker.io"

# Check if deployment has PodDisruptionBudget
has_pdb(deployment) if {
    deployment.spec.replicas > 1
    # This would need to check against actual PDB resources
    true
}

# Validate network policy
has_network_policy(pod) if {
    # Check if pod is covered by a network policy
    # This would need to check against actual NetworkPolicy resources
    pod.metadata.labels["network-policy"] == "enabled"
}

# Check RBAC permissions
excessive_permissions(role) if {
    role.rules[_].verbs[_] == "*"
} else if {
    role.rules[_].resources[_] == "*"
} else if {
    role.rules[_].apiGroups[_] == "*"
}

# Validate service mesh annotations
has_service_mesh(pod) if {
    pod.metadata.annotations["sidecar.istio.io/inject"] == "true"
} else if {
    pod.metadata.annotations["linkerd.io/inject"] == "enabled"
}

# Check pod priority
has_priority_class(pod) if {
    pod.spec.priorityClassName
}

# Validate pod anti-affinity
has_anti_affinity(pod) if {
    pod.spec.affinity.podAntiAffinity
}