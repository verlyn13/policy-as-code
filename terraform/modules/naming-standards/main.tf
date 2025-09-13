locals {
  naming_components = {
    resource_type = var.resource_abbreviation
    workload      = var.workload_name
    environment   = var.environment
    region        = var.region_code
    instance      = format("%03d", var.instance_number)
  }
  
  resource_name = join("-", [
    local.naming_components.resource_type,
    local.naming_components.workload,
    local.naming_components.environment,
    local.naming_components.region,
    local.naming_components.instance
  ])
  
  name_validation = regex(
    "^[a-z]{2,5}-[a-z0-9]{2,20}-(dev|stg|prod)-(hel1|fsn1|nbg1)-[0-9]{3}$",
    local.resource_name
  )
}

output "resource_name" {
  value = local.resource_name
  
  precondition {
    condition     = can(local.name_validation)
    error_message = "Resource name does not follow the required pattern: <type>-<workload>-<env>-<region>-<instance>"
  }
}