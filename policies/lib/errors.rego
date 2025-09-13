package lib.errors

import future.keywords.if

# Standardized error message format for all policies
# Provides consistent, actionable deny messages with references

# Generate standardized error message
format_error(policy_id, message, remediation) := error if {
    error := {
        "policy_id": policy_id,
        "message": message,
        "remediation": remediation,
        "documentation": sprintf("https://docs.verlyn13.dev/policies/%s", [policy_id]),
        "timestamp": time.now_ns(),
        "severity": get_severity(policy_id)
    }
}

# Get severity level based on policy ID prefix
get_severity(policy_id) := severity if {
    startswith(policy_id, "SEC-")
    severity := "critical"
} else := severity if {
    startswith(policy_id, "COMP-")
    severity := "high"
} else := severity if {
    startswith(policy_id, "PROF-")
    severity := "medium"
} else := "low"

# Common error messages with proper formatting
errors := {
    # Security errors (SEC-)
    "SEC-001": format_error(
        "SEC-001",
        "Pod does not meet security standards",
        "Ensure pod has security context with runAsNonRoot=true and readOnlyRootFilesystem=true"
    ),
    
    "SEC-002": format_error(
        "SEC-002",
        "Container image not from approved registry",
        "Use images only from approved registries listed in policy documentation"
    ),
    
    "SEC-003": format_error(
        "SEC-003",
        "SSH root login is enabled",
        "Set PermitRootLogin to 'no' in sshd_config"
    ),
    
    # Compliance errors (COMP-)
    "COMP-001": format_error(
        "COMP-001",
        "Resource missing required tags",
        "Add all mandatory tags: Owner, CostCenter, Environment, ApplicationId"
    ),
    
    "COMP-002": format_error(
        "COMP-002",
        "Backup not configured for production resource",
        "Enable backups with minimum 7-day retention for all production resources"
    ),
    
    "COMP-003": format_error(
        "COMP-003",
        "Monitoring not enabled for critical service",
        "Configure metrics, logs, and alerts for this service"
    ),
    
    # Profile errors (PROF-)
    "PROF-001": format_error(
        "PROF-001",
        "Invalid system profile specified",
        "Use one of: development_workstation, production_server, staging_server, ci_agent, container_runtime"
    ),
    
    "PROF-002": format_error(
        "PROF-002",
        "Production environment missing high security level",
        "Set security.level to 'high' for all production systems"
    ),
    
    "PROF-003": format_error(
        "PROF-003",
        "Required package not installed for profile",
        "Install all required packages for the selected system profile"
    ),
    
    # Terraform errors (TF-)
    "TF-001": format_error(
        "TF-001",
        "Terraform plan contains destructive changes",
        "Review plan carefully and confirm deletion is intended"
    ),
    
    "TF-002": format_error(
        "TF-002",
        "Resource name does not follow naming convention",
        "Use format: <type>-<workload>-<env>-<region>-<instance>"
    ),
    
    "TF-003": format_error(
        "TF-003",
        "Ephemeral resource pattern not used for secrets",
        "Use 'ephemeral' blocks instead of 'data' sources for secrets"
    ),
    
    # Kubernetes errors (K8S-)
    "K8S-001": format_error(
        "K8S-001",
        "Pod using privileged container",
        "Set privileged: false in security context"
    ),
    
    "K8S-002": format_error(
        "K8S-002",
        "Service exposed without network policy",
        "Create NetworkPolicy to restrict ingress/egress traffic"
    ),
    
    "K8S-003": format_error(
        "K8S-003",
        "Resource limits not defined",
        "Set CPU and memory limits for all containers"
    )
}

# Helper function to create custom error
custom_error(policy_id, message, remediation) := format_error(policy_id, message, remediation)