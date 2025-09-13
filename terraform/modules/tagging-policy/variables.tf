variable "owner_email" {
  description = "Email address of the resource owner"
  type        = string
}

variable "cost_center" {
  description = "Cost center code (format: CC####)"
  type        = string
}

variable "environment" {
  description = "Environment (dev, stg, prod)"
  type        = string
}

variable "application_id" {
  description = "Application identifier"
  type        = string
}

variable "data_classification" {
  description = "Data sensitivity classification (public, internal, confidential)"
  type        = string
}

variable "project_code" {
  description = "Project code"
  type        = string
  default     = null
}

variable "maintenance_window" {
  description = "Maintenance window specification"
  type        = string
  default     = null
}

variable "backup_required" {
  description = "Whether backups are required"
  type        = bool
  default     = null
}

variable "compliance_requirements" {
  description = "List of compliance requirements"
  type        = list(string)
  default     = []
}

variable "sla_percentage" {
  description = "SLA percentage (e.g., 99.9)"
  type        = string
  default     = null
}