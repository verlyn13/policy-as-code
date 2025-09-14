variable "app_slug" {
  description = "Short application slug"
  type        = string
}

variable "environments" {
  description = "Environments to create (e.g., [\"dev\", \"stg\", \"prod\"])"
  type        = list(string)
  default     = ["dev", "stg", "prod"]
}

variable "default_environment" {
  description = "Default environment for placeholders"
  type        = string
  default     = "dev"
}

variable "placeholder_secrets" {
  description = "List of secret names to create as placeholders (no values here)"
  type        = list(string)
  default     = []
}

