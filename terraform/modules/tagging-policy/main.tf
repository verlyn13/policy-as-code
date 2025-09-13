locals {
  mandatory_tags = {
    Owner            = var.owner_email
    CostCenter       = var.cost_center
    Environment      = var.environment
    ApplicationId    = var.application_id
    ManagedBy        = "terraform"
    DataSensitivity  = var.data_classification
    CreatedDate      = formatdate("YYYY-MM-DD", timestamp())
    TerraformVersion = "1.13.2"
  }
  
  optional_tags = {
    ProjectCode       = var.project_code
    MaintenanceWindow = var.maintenance_window
    BackupRequired    = var.backup_required
    Compliance        = join(",", var.compliance_requirements)
    SLA              = var.sla_percentage
  }
  
  all_tags = merge(
    local.mandatory_tags,
    { for k, v in local.optional_tags : k => v if v != null }
  )
}

resource "null_resource" "validate_tags" {
  lifecycle {
    precondition {
      condition = alltrue([
        can(regex("^[a-z0-9._%+-]+@[a-z0-9.-]+\\.[a-z]{2,}$", local.mandatory_tags.Owner)),
        can(regex("^CC[0-9]{4}$", local.mandatory_tags.CostCenter)),
        contains(["public", "internal", "confidential"], local.mandatory_tags.DataSensitivity),
        contains(["dev", "stg", "prod"], local.mandatory_tags.Environment)
      ])
      error_message = "Tag validation failed. Check Owner email, CostCenter format (CC####), and valid enum values."
    }
  }
}

output "tags" {
  value = local.all_tags
}