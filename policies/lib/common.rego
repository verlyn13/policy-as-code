package lib.common

import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Common utility functions shared across policies

# Check if a value exists in a list
contains_value(list, value) if {
    value in list
}

# Check if all required labels are present
has_required_labels(resource, required_labels) if {
    provided := object.keys(resource.metadata.labels)
    missing := required_labels - provided
    count(missing) == 0
}

# Check if resource has valid tags
has_valid_tags(resource, required_tags) if {
    provided := object.keys(resource.tags)
    missing := required_tags - provided
    count(missing) == 0
}

# Validate resource naming convention
valid_name(name, pattern) if {
    regex.match(pattern, name)
}

# Check if image is from allowed registry
allowed_image(image, registries) if {
    some registry in registries
    startswith(image, registry)
}

# Get severity level for violation
severity_level(violation_type) = level if {
    severity_map := {
        "security": "high",
        "compliance": "medium",
        "best_practice": "low"
    }
    level := severity_map[violation_type]
} else = "medium"

# Format violation message with metadata
format_violation(resource, rule, message) = formatted if {
    formatted := {
        "resource": resource_identifier(resource),
        "rule": rule,
        "message": message,
        "severity": severity_level(rule.type),
        "timestamp": time.now_ns()
    }
}

# Extract resource identifier
resource_identifier(resource) = id if {
    id := sprintf("%s/%s/%s", [
        resource.kind,
        resource.metadata.namespace,
        resource.metadata.name
    ])
} else = id if {
    id := sprintf("%s/%s", [
        resource.type,
        resource.name
    ])
} else = "unknown"

# Check resource limits
within_limits(value, min, max) if {
    value >= min
    value <= max
}

# Parse memory string to bytes
parse_memory(mem_string) = bytes if {
    # Handle Mi, Gi, Ki suffixes
    endswith(mem_string, "Gi")
    num := to_number(trim_suffix(mem_string, "Gi"))
    bytes := num * 1024 * 1024 * 1024
} else = bytes if {
    endswith(mem_string, "Mi")
    num := to_number(trim_suffix(mem_string, "Mi"))
    bytes := num * 1024 * 1024
} else = bytes if {
    endswith(mem_string, "Ki")
    num := to_number(trim_suffix(mem_string, "Ki"))
    bytes := num * 1024
} else = bytes if {
    bytes := to_number(mem_string)
}

# Parse CPU string to millicores
parse_cpu(cpu_string) = millicores if {
    endswith(cpu_string, "m")
    millicores := to_number(trim_suffix(cpu_string, "m"))
} else = millicores if {
    cores := to_number(cpu_string)
    millicores := cores * 1000
}