# System Profiles Module - Unified configuration for different system types
# Supports: development workstations, production servers, CI/CD agents, containers

locals {
  # Define system profiles with their specific requirements
  profiles = {
    development_workstation = {
      type        = "workstation"
      purpose     = "development"
      base_packages = concat(
        var.common_packages,
        var.development_packages,
        var.ai_tools_packages
      )
      services = ["docker", "podman", "ssh"]
      security_level = "moderate"
      backup_required = true
      monitoring = {
        metrics = true
        logs    = true
        traces  = true
      }
    }
    
    production_server = {
      type        = "server"
      purpose     = "production"
      base_packages = concat(
        var.common_packages,
        var.server_packages
      )
      services = ["firewalld", "fail2ban", "auditd"]
      security_level = "high"
      backup_required = true
      monitoring = {
        metrics = true
        logs    = true
        traces  = true
        alerts  = true
      }
    }
    
    staging_server = {
      type        = "server"
      purpose     = "staging"
      base_packages = concat(
        var.common_packages,
        var.server_packages,
        var.testing_packages
      )
      services = ["firewalld", "docker"]
      security_level = "moderate"
      backup_required = true
      monitoring = {
        metrics = true
        logs    = true
        traces  = false
      }
    }
    
    ci_agent = {
      type        = "agent"
      purpose     = "ci"
      base_packages = concat(
        var.common_packages,
        var.ci_packages
      )
      services = ["docker", "buildkit"]
      security_level = "moderate"
      backup_required = false
      monitoring = {
        metrics = true
        logs    = true
        traces  = false
      }
    }
    
    container_runtime = {
      type        = "container"
      purpose     = "application"
      base_packages = var.container_packages
      services = []
      security_level = "high"
      backup_required = false
      monitoring = {
        metrics = true
        logs    = true
        traces  = true
      }
    }
  }
  
  selected_profile = local.profiles[var.system_profile]
  
  # Environment-specific overrides
  environment_config = {
    dev = {
      security_patches_auto = false
      debug_enabled        = true
      log_level           = "debug"
    }
    stg = {
      security_patches_auto = true
      debug_enabled        = true
      log_level           = "info"
    }
    prod = {
      security_patches_auto = true
      debug_enabled        = false
      log_level           = "warning"
    }
  }
  
  final_config = merge(
    local.selected_profile,
    local.environment_config[var.environment]
  )
}

# Generate system configuration based on profile
resource "local_file" "system_config" {
  filename = "${path.module}/generated/${var.system_name}-config.yaml"
  content = yamlencode({
    system = {
      name        = var.system_name
      profile     = var.system_profile
      environment = var.environment
      type        = local.selected_profile.type
      purpose     = local.selected_profile.purpose
    }
    
    packages = {
      base     = local.selected_profile.base_packages
      runtime  = var.runtime_packages
      optional = var.optional_packages
    }
    
    services = {
      enabled  = local.selected_profile.services
      disabled = var.disabled_services
    }
    
    security = {
      level              = local.selected_profile.security_level
      patches_auto       = local.final_config.security_patches_auto
      firewall_enabled   = contains(["high", "moderate"], local.selected_profile.security_level)
      selinux_mode      = local.selected_profile.security_level == "high" ? "enforcing" : "permissive"
      audit_enabled     = local.selected_profile.security_level == "high"
    }
    
    monitoring = local.selected_profile.monitoring
    
    backup = {
      enabled   = local.selected_profile.backup_required
      frequency = local.selected_profile.backup_required ? var.backup_frequency : null
      retention = local.selected_profile.backup_required ? var.backup_retention : null
    }
    
    logging = {
      level       = local.final_config.log_level
      debug       = local.final_config.debug_enabled
      destination = var.log_destination
    }
  })
}

# Profile-specific configurations
module "workstation_config" {
  count  = local.selected_profile.type == "workstation" ? 1 : 0
  source = "../workstation-setup"
  
  username          = var.workstation_user
  dotfiles_repo     = var.dotfiles_repo
  ai_tools_enabled  = true
  development_tools = var.development_tools
}

module "server_config" {
  count  = local.selected_profile.type == "server" ? 1 : 0
  source = "../server-hardening"
  
  server_name      = var.system_name
  security_level   = local.selected_profile.security_level
  network_config   = var.server_network_config
  ssl_certificates = var.ssl_certificates
}

module "container_config" {
  count  = local.selected_profile.type == "container" ? 1 : 0
  source = "../container-runtime"
  
  base_image      = var.container_base_image
  runtime         = var.container_runtime
  security_opts   = var.container_security_opts
  resource_limits = var.container_resource_limits
}

output "system_configuration" {
  value = {
    profile      = var.system_profile
    type         = local.selected_profile.type
    environment  = var.environment
    config_path  = local_file.system_config.filename
    services     = local.selected_profile.services
    monitoring   = local.selected_profile.monitoring
  }
}

output "validation_rules" {
  value = {
    requires_backup     = local.selected_profile.backup_required
    security_level      = local.selected_profile.security_level
    monitoring_enabled  = local.selected_profile.monitoring
    patch_management    = local.final_config.security_patches_auto
  }
}