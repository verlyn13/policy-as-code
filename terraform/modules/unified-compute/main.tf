# Unified compute module for both servers and containers
# Abstracts infrastructure provisioning across different compute types

locals {
  compute_type = var.compute_type # "server" or "container"
  
  # Common configuration regardless of compute type
  base_config = {
    name        = module.naming.resource_name
    environment = var.environment
    tags        = module.tagging.tags
  }
  
  # Server-specific configuration
  server_config = local.compute_type == "server" ? {
    server_type = var.server_type
    location    = var.location
    ssh_keys    = var.ssh_keys
    network_id  = var.network_id
    firewall_id = var.firewall_id
  } : {}
  
  # Container-specific configuration
  container_config = local.compute_type == "container" ? {
    image           = var.container_image
    cpu_limit       = var.container_cpu
    memory_limit    = var.container_memory
    port_mappings   = var.container_ports
    environment_vars = var.container_env_vars
  } : {}
}

module "naming" {
  source = "../naming-standards"
  
  resource_abbreviation = local.compute_type == "server" ? "hcs" : "hcc"
  workload_name        = var.workload_name
  environment          = var.environment
  region_code          = var.region_code
  instance_number      = var.instance_number
}

module "tagging" {
  source = "../tagging-policy"
  
  owner_email           = var.owner_email
  cost_center          = var.cost_center
  environment          = var.environment
  application_id       = var.application_id
  data_classification  = var.data_classification
  project_code         = var.project_code
  backup_required      = var.backup_required
  compliance_requirements = var.compliance_requirements
  sla_percentage       = var.sla_percentage
}

# Hetzner Cloud Server resource (conditional)
resource "hcloud_server" "compute" {
  count = local.compute_type == "server" ? 1 : 0
  
  name        = local.base_config.name
  server_type = local.server_config.server_type
  location    = local.server_config.location
  image       = var.server_image
  
  ssh_keys = local.server_config.ssh_keys
  
  network {
    network_id = local.server_config.network_id
    ip         = var.private_ip
  }
  
  firewall_ids = [local.server_config.firewall_id]
  
  labels = local.base_config.tags
  
  user_data = var.user_data
  
  lifecycle {
    ignore_changes = [ssh_keys]
  }
}

# Future: Container orchestration resources can be added here
# resource "kubernetes_deployment" "compute" { ... }
# resource "docker_container" "compute" { ... }

output "compute_id" {
  value = local.compute_type == "server" ? try(hcloud_server.compute[0].id, null) : null
}

output "compute_ip" {
  value = local.compute_type == "server" ? try(hcloud_server.compute[0].ipv4_address, null) : null
}

output "compute_name" {
  value = local.base_config.name
}