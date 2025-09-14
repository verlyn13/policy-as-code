variable "name" {
  description = "Approval policy name"
  type        = string
}

variable "environment" {
  description = "Environment target (dev|stg|prod)"
  type        = string
}

variable "approver_group_ids" {
  description = "List of Infisical group IDs that can approve"
  type        = list(string)
}

variable "webhook_url" {
  description = "Optional webhook URL for notifications"
  type        = string
  default     = null
}

