package docker.security

import data.lib.common
import future.keywords.contains
import future.keywords.if
import future.keywords.in

# METADATA
# title: Docker Security Policy
# description: Enforces security best practices for Docker images and containers
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

# Allowed base image registries
allowed_registries := {
    "docker.io/library/",
    "gcr.io/",
    "registry.access.redhat.com/",
    "quay.io/"
}

# Denied base images
denied_images := {
    "ubuntu:latest",
    "alpine:latest",
    "node:latest",
    "python:latest"
}

# Deny using latest tag
deny[msg] {
    input.config.Image
    endswith(input.config.Image, ":latest")
    msg := "Container must not use 'latest' tag"
}

# Deny untrusted base images
deny[msg] {
    input.config.Image
    not common.allowed_image(input.config.Image, allowed_registries)
    msg := sprintf("Image '%s' is not from an allowed registry", [input.config.Image])
}

# Deny running as root
deny[msg] {
    input.config.User == ""
    msg := "Container must not run as root user"
}

deny[msg] {
    input.config.User == "root"
    msg := "Container must not run as root user"
}

deny[msg] {
    input.config.User == "0"
    msg := "Container must not run as root user (UID 0)"
}

# Deny privileged containers
deny[msg] {
    input.host_config.Privileged == true
    msg := "Container must not run in privileged mode"
}

# Deny containers with CAP_SYS_ADMIN
deny[msg] {
    "CAP_SYS_ADMIN" in input.host_config.CapAdd
    msg := "Container must not have CAP_SYS_ADMIN capability"
}

# Deny containers that can escalate privileges
deny[msg] {
    input.host_config.SecurityOpt[_] == "no-new-privileges=false"
    msg := "Container must not be able to gain new privileges"
}

# Require health checks
deny[msg] {
    not input.config.Healthcheck
    msg := "Container must define a health check"
}

# Deny mounting sensitive host paths
sensitive_paths := {
    "/",
    "/etc",
    "/var/run/docker.sock",
    "/proc",
    "/sys"
}

deny[msg] {
    mount := input.host_config.Mounts[_]
    mount.Source in sensitive_paths
    msg := sprintf("Container must not mount sensitive path: %s", [mount.Source])
}

# Require resource limits
deny[msg] {
    not input.host_config.Memory
    msg := "Container must specify memory limits"
}

deny[msg] {
    not input.host_config.CpuQuota
    msg := "Container must specify CPU limits"
}

# Require read-only root filesystem
deny[msg] {
    input.host_config.ReadonlyRootfs != true
    msg := "Container should have read-only root filesystem"
}

# Deny containers with host network mode
deny[msg] {
    input.host_config.NetworkMode == "host"
    msg := "Container must not use host network mode"
}

# Deny containers with host PID namespace
deny[msg] {
    input.host_config.PidMode == "host"
    msg := "Container must not use host PID namespace"
}

# Generate decision record
decision = {
    "allowed": allow,
    "denials": deny,
    "image": input.config.Image,
    "timestamp": time.now_ns()
}