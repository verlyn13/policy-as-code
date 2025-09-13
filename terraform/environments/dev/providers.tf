terraform {
  required_version = ">= 1.13.2"
  required_providers {
    infisical = {
      source  = "infisical/infisical"
      version = "~> 0.15.0"
    }
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.48.0"
    }
  }
}

provider "infisical" {
  host = var.infisical_host
  
  auth {
    universal {
      client_id     = var.infisical_client_id
      client_secret = var.infisical_client_secret
    }
  }
}

provider "hcloud" {
  token = ephemeral.infisical_secret.hcloud_token.value
}

ephemeral "infisical_secret" "hcloud_token" {
  name         = "HCLOUD_TOKEN"
  env_slug     = "dev"
  workspace_id = var.infisical_workspace_id
  folder_path  = "/infrastructure/hetzner"
}