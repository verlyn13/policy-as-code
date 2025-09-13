variable "compute_type" {
  description = "Type of compute resource (server or container)"
  type        = string
  validation {
    condition     = contains(["server", "container"], var.compute_type)
    error_message = "Compute type must be 'server' or 'container'"
  }
}

variable "workload_name" {
  description = "Workload or application name"
  type        = string
}

variable "environment" {
  description = "Environment (dev, stg, prod)"
  type        = string
}

variable "region_code" {
  description = "Region code"
  type        = string
}

variable "instance_number" {
  description = "Instance number"
  type        = number
}

# Server-specific variables
variable "server_type" {
  description = "Hetzner server type (e.g., cx11, cx21)"
  type        = string
  default     = null
}

variable "server_image" {
  description = "Server image (e.g., ubuntu-22.04)"
  type        = string
  default     = "ubuntu-22.04"
}

variable "location" {
  description = "Server location"
  type        = string
  default     = null
}

variable "ssh_keys" {
  description = "List of SSH key IDs"
  type        = list(string)
  default     = []
}

variable "network_id" {
  description = "Network ID for server"
  type        = string
  default     = null
}

variable "firewall_id" {
  description = "Firewall ID for server"
  type        = string
  default     = null
}

variable "private_ip" {
  description = "Private IP address"
  type        = string
  default     = null
}

variable "user_data" {
  description = "Cloud-init user data"
  type        = string
  default     = null
}

# Container-specific variables
variable "container_image" {
  description = "Container image"
  type        = string
  default     = null
}

variable "container_cpu" {
  description = "CPU limit for container"
  type        = string
  default     = null
}

variable "container_memory" {
  description = "Memory limit for container"
  type        = string
  default     = null
}

variable "container_ports" {
  description = "Port mappings for container"
  type        = list(object({
    internal = number
    external = number
    protocol = string
  }))
  default = []
}

variable "container_env_vars" {
  description = "Environment variables for container"
  type        = map(string)
  default     = {}
}

# Tagging variables
variable "owner_email" {
  description = "Owner email for tagging"
  type        = string
}

variable "cost_center" {
  description = "Cost center for tagging"
  type        = string
}

variable "application_id" {
  description = "Application ID for tagging"
  type        = string
}

variable "data_classification" {
  description = "Data classification for tagging"
  type        = string
}

variable "project_code" {
  description = "Project code for tagging"
  type        = string
  default     = null
}

variable "backup_required" {
  description = "Whether backups are required"
  type        = bool
  default     = false
}

variable "compliance_requirements" {
  description = "List of compliance requirements"
  type        = list(string)
  default     = []
}

variable "sla_percentage" {
  description = "SLA percentage"
  type        = string
  default     = null
}