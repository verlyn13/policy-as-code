variable "resource_abbreviation" {
  description = "Resource type abbreviation (e.g., hcs for Hetzner Cloud Server)"
  type        = string
  validation {
    condition     = can(regex("^[a-z]{2,5}$", var.resource_abbreviation))
    error_message = "Resource abbreviation must be 2-5 lowercase letters"
  }
}

variable "workload_name" {
  description = "Workload or application name"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9]{2,20}$", var.workload_name))
    error_message = "Workload name must be 2-20 lowercase alphanumeric characters"
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

variable "region_code" {
  description = "Region code (hel1, fsn1, nbg1)"
  type        = string
  validation {
    condition     = contains(["hel1", "fsn1", "nbg1"], var.region_code)
    error_message = "Region code must be hel1, fsn1, or nbg1"
  }
}

variable "instance_number" {
  description = "Instance number (1-999)"
  type        = number
  validation {
    condition     = var.instance_number >= 1 && var.instance_number <= 999
    error_message = "Instance number must be between 1 and 999"
  }
}

variable "resource_abbreviations" {
  type = map(string)
  default = {
    hetzner_server    = "hcs"
    hetzner_firewall  = "hcfw"
    hetzner_network   = "hcn"
    hetzner_volume    = "hcv"
    infisical_project = "prj"
    infisical_group   = "grp"
    terraform_workspace = "tfw"
  }
}