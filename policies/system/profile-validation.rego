package system.profile.validation

import data.lib.common
import future.keywords.contains
import future.keywords.if
import future.keywords.in

# Validate system profiles and configurations

# Define valid system profiles
valid_profiles := {
    "development_workstation",
    "production_server",
    "staging_server",
    "ci_agent",
    "container_runtime"
}

# Define required configurations per profile
required_configs := {
    "development_workstation": {
        "packages": ["git", "docker", "python3"],
        "services": ["ssh"],
        "security_level": ["moderate", "low"],
        "user_required": true
    },
    "production_server": {
        "packages": ["firewalld", "fail2ban", "auditd"],
        "services": ["firewalld", "auditd"],
        "security_level": ["high"],
        "monitoring_required": true,
        "backup_required": true
    },
    "staging_server": {
        "packages": ["firewalld", "docker"],
        "services": ["firewalld"],
        "security_level": ["moderate", "high"],
        "monitoring_required": true
    },
    "ci_agent": {
        "packages": ["docker", "git"],
        "services": ["docker"],
        "security_level": ["moderate"],
        "cache_required": true
    },
    "container_runtime": {
        "packages": ["ca-certificates"],
        "services": [],
        "security_level": ["high"],
        "resource_limits_required": true
    }
}

# Validate profile exists
deny contains msg if {
    not input.system_profile in valid_profiles
    msg := sprintf("Invalid system profile: %s. Must be one of: %v", 
        [input.system_profile, valid_profiles])
}

# Validate environment
deny contains msg if {
    not input.environment in {"dev", "stg", "prod"}
    msg := sprintf("Invalid environment: %s. Must be dev, stg, or prod", 
        [input.environment])
}

# Validate required packages are present
deny contains msg if {
    profile := input.system_profile
    required := required_configs[profile].packages[_]
    not common.contains_value(input.packages, required)
    msg := sprintf("Profile %s requires package: %s", [profile, required])
}

# Validate required services are enabled
deny contains msg if {
    profile := input.system_profile
    required := required_configs[profile].services[_]
    not common.contains_value(input.services.enabled, required)
    msg := sprintf("Profile %s requires service: %s", [profile, required])
}

# Validate security level
deny contains msg if {
    profile := input.system_profile
    allowed_levels := required_configs[profile].security_level
    not input.security.level in allowed_levels
    msg := sprintf("Profile %s requires security level to be one of: %v", 
        [profile, allowed_levels])
}

# Production-specific validations
deny contains msg if {
    input.environment == "prod"
    input.security.level != "high"
    msg := "Production environment must have security level 'high'"
}

deny contains msg if {
    input.environment == "prod"
    not input.backup.enabled
    msg := "Production environment must have backups enabled"
}

deny contains msg if {
    input.environment == "prod"
    not input.monitoring.alerts
    msg := "Production environment must have monitoring alerts enabled"
}

# Development workstation validations
deny contains msg if {
    input.system_profile == "development_workstation"
    not input.workstation_user
    msg := "Development workstation requires workstation_user to be set"
}

deny contains msg if {
    input.system_profile == "development_workstation"
    count(input.ai_tools) == 0
    msg := "Development workstation should have at least one AI tool configured"
}

# Server validations
deny contains msg if {
    contains(input.system_profile, "server")
    not input.firewall.enabled
    msg := sprintf("Server profile %s must have firewall enabled", 
        [input.system_profile])
}

deny contains msg if {
    contains(input.system_profile, "server")
    input.ssh.permit_root_login
    msg := "Servers must not permit root SSH login"
}

deny contains msg if {
    contains(input.system_profile, "server")
    input.ssh.password_authentication
    msg := "Servers must use key-based SSH authentication only"
}

# Container runtime validations
deny contains msg if {
    input.system_profile == "container_runtime"
    not input.container.resource_limits
    msg := "Container runtime must define resource limits"
}

deny contains msg if {
    input.system_profile == "container_runtime"
    not input.container.security_opts
    msg := "Container runtime must define security options"
}

# CI agent validations
deny contains msg if {
    input.system_profile == "ci_agent"
    not input.docker.enabled
    not input.podman.enabled
    msg := "CI agent must have either Docker or Podman enabled"
}

# Backup validations
deny contains msg if {
    input.backup.enabled
    not input.backup.frequency in {"hourly", "daily", "weekly", "monthly"}
    msg := sprintf("Invalid backup frequency: %s", [input.backup.frequency])
}

deny contains msg if {
    input.backup.enabled
    input.backup.retention < 7
    msg := "Backup retention must be at least 7 days"
}

# Monitoring validations
warn contains msg if {
    input.monitoring.metrics
    not input.monitoring.logs
    msg := "Metrics enabled but logs disabled - consider enabling both"
}

warn contains msg if {
    input.environment != "prod"
    input.monitoring.alerts
    msg := "Alerts enabled in non-production - this may generate noise"
}

# Resource limit validations for containers
deny contains msg if {
    input.container.resource_limits.memory
    not regex.match("^[0-9]+(m|Mi|g|Gi)$", input.container.resource_limits.memory)
    msg := sprintf("Invalid memory limit format: %s", 
        [input.container.resource_limits.memory])
}

deny contains msg if {
    input.container.resource_limits.cpu_shares < 128
    msg := "CPU shares must be at least 128"
}

# Network configuration validations
deny contains msg if {
    some iface in input.network.interfaces
    iface.ip
    not regex.match("^([0-9]{1,3}\\.){3}[0-9]{1,3}$", iface.ip)
    msg := sprintf("Invalid IP address format: %s", [iface.ip])
}

# Package version validations
warn contains msg if {
    pkg := input.packages[_]
    pkg.version == "latest"
    msg := sprintf("Package %s uses 'latest' version - consider pinning version", 
        [pkg.name])
}

# Summary validation score
validation_score := score if {
    total_checks := count(deny) + count(warn)
    passed := count(input) - total_checks
    score := (passed / count(input)) * 100
}

# Overall validation result
allow if {
    count(deny) == 0
}

validation_summary := summary if {
    summary := {
        "profile": input.system_profile,
        "environment": input.environment,
        "errors": [msg | deny[msg]],
        "warnings": [msg | warn[msg]],
        "score": validation_score,
        "valid": allow
    }
}
