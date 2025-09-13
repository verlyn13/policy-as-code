variable "system_name" {
  description = "Name of the system being configured"
  type        = string
}

variable "system_profile" {
  description = "System profile to apply"
  type        = string
  validation {
    condition = contains([
      "development_workstation",
      "production_server",
      "staging_server",
      "ci_agent",
      "container_runtime"
    ], var.system_profile)
    error_message = "Invalid system profile. Must be one of: development_workstation, production_server, staging_server, ci_agent, container_runtime"
  }
}

variable "environment" {
  description = "Environment (dev, stg, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "stg", "prod"], var.environment)
    error_message = "Environment must be dev, stg, or prod"
  }
}

# Package variables
variable "common_packages" {
  description = "Common packages for all systems"
  type        = list(string)
  default = [
    "git",
    "curl",
    "wget",
    "vim",
    "htop",
    "tmux",
    "jq"
  ]
}

variable "development_packages" {
  description = "Development workstation packages"
  type        = list(string)
  default = [
    "gcc",
    "make",
    "docker",
    "podman",
    "nodejs",
    "python3",
    "rust",
    "go"
  ]
}

variable "ai_tools_packages" {
  description = "AI development tools"
  type        = list(string)
  default = [
    "ollama",
    "python3-openai",
    "python3-anthropic"
  ]
}

variable "server_packages" {
  description = "Server-specific packages"
  type        = list(string)
  default = [
    "firewalld",
    "fail2ban",
    "auditd",
    "rsyslog"
  ]
}

variable "testing_packages" {
  description = "Testing and staging packages"
  type        = list(string)
  default = [
    "stress",
    "sysbench",
    "ab"
  ]
}

variable "ci_packages" {
  description = "CI/CD agent packages"
  type        = list(string)
  default = [
    "docker",
    "buildah",
    "skopeo",
    "ansible"
  ]
}

variable "container_packages" {
  description = "Container runtime packages"
  type        = list(string)
  default = [
    "ca-certificates",
    "tzdata"
  ]
}

variable "runtime_packages" {
  description = "Additional runtime packages"
  type        = list(string)
  default = []
}

variable "optional_packages" {
  description = "Optional packages to install"
  type        = list(string)
  default = []
}

variable "disabled_services" {
  description = "Services to explicitly disable"
  type        = list(string)
  default = []
}

# Workstation-specific variables
variable "workstation_user" {
  description = "Primary user for workstation"
  type        = string
  default     = ""
}

variable "dotfiles_repo" {
  description = "Dotfiles repository URL"
  type        = string
  default     = ""
}

variable "development_tools" {
  description = "Development tools configuration"
  type = map(object({
    enabled = bool
    version = string
    config  = map(string)
  }))
  default = {}
}

# Server-specific variables
variable "server_network_config" {
  description = "Server network configuration"
  type = object({
    interfaces = list(object({
      name    = string
      ip      = string
      netmask = string
      gateway = string
    }))
    dns_servers = list(string)
    firewall_rules = list(object({
      port     = number
      protocol = string
      source   = string
    }))
  })
  default = null
}

variable "ssl_certificates" {
  description = "SSL certificate configuration"
  type = map(object({
    cert_path = string
    key_path  = string
    ca_path   = string
  }))
  default = {}
}

# Container-specific variables
variable "container_base_image" {
  description = "Base container image"
  type        = string
  default     = "alpine:latest"
}

variable "container_runtime" {
  description = "Container runtime (docker, podman, containerd)"
  type        = string
  default     = "podman"
}

variable "container_security_opts" {
  description = "Container security options"
  type        = list(string)
  default = [
    "no-new-privileges",
    "seccomp=unconfined"
  ]
}

variable "container_resource_limits" {
  description = "Container resource limits"
  type = object({
    cpu_shares = number
    memory     = string
    pids_limit = number
  })
  default = {
    cpu_shares = 1024
    memory     = "512m"
    pids_limit = 100
  }
}

# Backup configuration
variable "backup_frequency" {
  description = "Backup frequency (daily, weekly, monthly)"
  type        = string
  default     = "daily"
}

variable "backup_retention" {
  description = "Backup retention in days"
  type        = number
  default     = 30
}

# Logging configuration
variable "log_destination" {
  description = "Log destination (local, remote, both)"
  type        = string
  default     = "local"
}