variable "service_name" {
  description = "Base service name"
  type        = string
}

variable "environment" {
  description = "Environment slug (dev|stg|prod)"
  type        = string
}

variable "identity_role" {
  description = "Infisical identity role"
  type        = string
  default     = "machine"
}

variable "client_secret_ttl" {
  description = "TTL for client secret in seconds (<= 7200)"
  type        = number
  default     = 3600
}

variable "access_token_ttl" {
  description = "TTL for access token in seconds (<= 1800)"
  type        = number
  default     = 900
}

variable "access_token_max_ttl" {
  description = "Max TTL for access token in seconds (<= 3600)"
  type        = number
  default     = 3600
}

variable "access_token_num_uses" {
  description = "Max uses for access token (<= 100)"
  type        = number
  default     = 50
}

variable "trusted_ips" {
  description = "List of CIDRs/IPs allowed to use tokens"
  type        = list(string)
  default     = []
}

