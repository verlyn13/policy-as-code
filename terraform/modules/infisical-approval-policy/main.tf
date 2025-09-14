terraform {
  required_version = ">= 1.13.2"
  required_providers {
    infisical = {
      source  = "infisical/infisical"
      version = "~> 0.15.0"
    }
  }
}

resource "infisical_approval_policy" "this" {
  name        = var.name
  environment = var.environment

  approver_group_ids = var.approver_group_ids

  dynamic "notifications" {
    for_each = var.webhook_url == null ? [] : [1]
    content {
      webhook_url = var.webhook_url
    }
  }
}

