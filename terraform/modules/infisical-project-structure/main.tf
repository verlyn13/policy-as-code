terraform {
  required_version = ">= 1.13.2"
  required_providers {
    infisical = {
      source  = "infisical/infisical"
      version = "~> 0.15.0"
    }
  }
}

locals {
  envs = var.environments
}

# Create standardized folder structure per environment
resource "infisical_folder" "structure" {
  for_each = { for env in local.envs : env => env }
  path     = "/${each.key}/${var.app_slug}"
}

# Optionally create placeholder secrets (names only, no values)
resource "infisical_secret" "placeholders" {
  for_each = { for s in var.placeholder_secrets : s => s }
  name     = each.key
  path     = "/${var.default_environment}/${var.app_slug}"
  value    = "PLACEHOLDER" # Placeholder only; overwrite via runtime pipelines

  lifecycle {
    ignore_changes = [value]
  }
}

