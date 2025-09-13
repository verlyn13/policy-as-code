variable "infisical_host" {
  description = "Infisical API host URL"
  type        = string
  default     = "https://secrets.jefahnierocks.com"
}

variable "infisical_client_id" {
  description = "Infisical Universal Auth client ID"
  type        = string
  sensitive   = true
}

variable "infisical_client_secret" {
  description = "Infisical Universal Auth client secret"
  type        = string
  sensitive   = true
}

variable "infisical_workspace_id" {
  description = "Infisical workspace ID"
  type        = string
}

variable "hetzner_private_ips" {
  description = "List of Hetzner private IPs for access control"
  type        = list(string)
  default     = []
}

variable "office_ips" {
  description = "List of office IPs for access control"
  type        = list(string)
  default     = []
}