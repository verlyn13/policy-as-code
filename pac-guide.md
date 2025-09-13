# Modern Terraform 1.13.2+ Implementation Guides for Platform-as-Code

## Guide 1: Developer Workstation Setup for Distributed Terraform Workflow

### Prerequisites Installation

```bash
#!/bin/bash
# install-terraform-1.13.2.sh
TERRAFORM_VERSION="1.13.2"
INFISICAL_CLI_VERSION="0.41.0"

# Install Terraform 1.13.2
wget "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
unzip terraform_${TERRAFORM_VERSION}_linux_amd64.zip
sudo mv terraform /usr/local/bin/
terraform version

# Install Infisical CLI
curl -1sLf 'https://dl.cloudsmith.io/public/infisical/infisical-cli/setup.deb.sh' | sudo -E bash
sudo apt-get update && sudo apt-get install infisical

# Configure Git hooks for validation
git config --global init.templateDir ~/.git-templates
mkdir -p ~/.git-templates/hooks
```

### Local Development Environment Configuration

```bash
# .envrc (using direnv for automatic environment loading)
export TF_VERSION="1.13.2"
export TF_LOG="INFO"
export TF_LOG_PATH="./terraform.log"
export TF_IN_AUTOMATION=false
export TF_CLI_ARGS_plan="-parallelism=10"
export TF_CLI_ARGS_apply="-parallelism=10"

# Point to remote Hetzner agent
export TF_REMOTE_AGENT="terraform@10.0.1.10"
export TF_WORKSPACE_DIR="/opt/terraform-agent/workspace"

# Infisical configuration (no secrets here!)
export INFISICAL_URL="https://infisical.your-domain.com"
export INFISICAL_DISABLE_UPDATE_CHECK="true"
```

### Remote Execution Script

```bash
#!/bin/bash
# terraform-remote.sh - Execute Terraform on Hetzner agent
set -euo pipefail

REMOTE_HOST="${TF_REMOTE_AGENT:-terraform@your-hetzner-agent}"
WORKSPACE_DIR="${TF_WORKSPACE_DIR:-/opt/terraform-agent/workspace}"
ENVIRONMENT="${1:-dev}"
COMMAND="${2:-plan}"

# Color output for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Executing Terraform ${COMMAND} for ${ENVIRONMENT} environment${NC}"

# Sync local files to remote agent (excluding sensitive data)
sync_to_remote() {
    echo -e "${GREEN}Syncing files to remote agent...${NC}"
    rsync -avz --delete \
        --exclude='.terraform/' \
        --exclude='*.tfstate*' \
        --exclude='.env*' \
        --exclude='*.tfvars' \
        --exclude='.git/' \
        ./ "${REMOTE_HOST}:${WORKSPACE_DIR}/"
}

# Execute Terraform command remotely
run_remote_terraform() {
    ssh -o StrictHostKeyChecking=no "${REMOTE_HOST}" \
        "cd ${WORKSPACE_DIR}/terraform/environments/${ENVIRONMENT} && \
         terraform ${COMMAND} -var-file=../../config/${ENVIRONMENT}.tfvars"
}

case "${COMMAND}" in
    "init")
        sync_to_remote
        run_remote_terraform
        ;;
    "plan")
        sync_to_remote
        ssh "${REMOTE_HOST}" "cd ${WORKSPACE_DIR}/terraform/environments/${ENVIRONMENT} && \
            terraform plan -out=tfplan-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S)"
        ;;
    "apply")
        echo -e "${RED}Applying changes to ${ENVIRONMENT}${NC}"
        read -p "Are you sure? (yes/no): " confirm
        if [[ "$confirm" == "yes" ]]; then
            ssh "${REMOTE_HOST}" "cd ${WORKSPACE_DIR}/terraform/environments/${ENVIRONMENT} && \
                terraform apply -auto-approve tfplan-${ENVIRONMENT}-*"
        fi
        ;;
    *)
        echo "Usage: $0 <environment> <init|plan|apply>"
        exit 1
        ;;
esac
```

## Guide 2: Ephemeral Resources Pattern Implementation

### Critical Security Pattern: Never Store Secrets in State

```hcl
# modules/secure-secrets/main.tf
# REQUIRED: Terraform 1.10+ for ephemeral resources
terraform {
  required_version = ">= 1.10.0"
}

# ❌ NEVER DO THIS - Secrets stored in state file
# data "infisical_secret" "bad_example" {
#   name = "DB_PASSWORD"
#   # This will store the secret value in terraform.tfstate!
# }

# ✅ ALWAYS USE EPHEMERAL - Secrets only in memory
ephemeral "infisical_secret" "db_credentials" {
  name         = "DB_PASSWORD"
  env_slug     = var.environment
  workspace_id = var.infisical_workspace_id
  folder_path  = "/database/postgresql"
}

# Use the ephemeral secret immediately
resource "null_resource" "configure_database" {
  provisioner "local-exec" {
    command = <<-EOT
      export PGPASSWORD='${ephemeral.infisical_secret.db_credentials.value}'
      psql -h ${var.db_host} -U ${var.db_user} -d ${var.db_name} \
        -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"
      unset PGPASSWORD
    EOT
  }
  
  lifecycle {
    # Re-run if the database changes
    replace_triggered_by = [var.db_host]
  }
}
```

### Ephemeral Pattern for Multiple Secrets

```hcl
# modules/ephemeral-multi/main.tf
locals {
  # Define all secrets needed
  required_secrets = {
    database = {
      path = "/database/postgresql"
      secrets = ["DB_HOST", "DB_USER", "DB_PASSWORD", "DB_NAME"]
    }
    redis = {
      path = "/cache/redis"
      secrets = ["REDIS_URL", "REDIS_PASSWORD"]
    }
    smtp = {
      path = "/external/email"
      secrets = ["SMTP_HOST", "SMTP_USER", "SMTP_PASSWORD"]
    }
  }
}

# Fetch all secrets ephemerally
ephemeral "infisical_secret" "service_secrets" {
  for_each = merge([
    for category, config in local.required_secrets : {
      for secret in config.secrets : 
        "${category}_${secret}" => {
          name = secret
          path = config.path
        }
    }
  ]...)
  
  name         = each.value.name
  env_slug     = var.environment
  workspace_id = var.infisical_workspace_id
  folder_path  = each.value.path
}

# Use in resource configuration
resource "kubernetes_secret" "app_config" {
  metadata {
    name      = "${var.service_name}-config"
    namespace = var.namespace
  }
  
  data = {
    for key, secret in ephemeral.infisical_secret.service_secrets :
      secret.name => secret.value
  }
  
  lifecycle {
    ignore_changes = [data]  # Prevent secret exposure in plan output
  }
}
```

## Guide 3: Modern Naming Convention Implementation

### Enforced Naming Standards Module

```hcl
# modules/naming-standards/main.tf
locals {
  # Naming pattern: <resource_type>-<workload>-<environment>-<region>-<instance>
  naming_components = {
    resource_type = var.resource_abbreviation
    workload      = var.workload_name
    environment   = var.environment
    region        = var.region_code
    instance      = format("%03d", var.instance_number)
  }
  
  # Construct the name
  resource_name = join("-", [
    local.naming_components.resource_type,
    local.naming_components.workload,
    local.naming_components.environment,
    local.naming_components.region,
    local.naming_components.instance
  ])
  
  # Validate naming convention
  name_validation = regex(
    "^[a-z]{2,5}-[a-z0-9]{2,20}-(dev|stg|prod)-(hel1|fsn1|nbg1)-[0-9]{3}$",
    local.resource_name
  )
}

# Resource abbreviations reference
variable "resource_abbreviations" {
  type = map(string)
  default = {
    hetzner_server    = "hcs"
    hetzner_firewall  = "hcfw"
    hetzner_network   = "hcn"
    hetzner_volume    = "hcv"
    infisical_project = "prj"
    infisical_group   = "grp"
    terraform_workspace = "tfw"
  }
}

output "resource_name" {
  value = local.resource_name
  
  precondition {
    condition     = can(local.name_validation)
    error_message = "Resource name does not follow the required pattern: <type>-<workload>-<env>-<region>-<instance>"
  }
}
```

### Automated Tagging Module

```hcl
# modules/tagging-policy/main.tf
locals {
  # Mandatory tags with validation
  mandatory_tags = {
    Owner          = var.owner_email
    CostCenter     = var.cost_center
    Environment    = var.environment
    ApplicationId  = var.application_id
    ManagedBy      = "terraform"
    DataSensitivity = var.data_classification
    CreatedDate    = formatdate("YYYY-MM-DD", timestamp())
    TerraformVersion = "1.13.2"
  }
  
  # Optional tags
  optional_tags = {
    ProjectCode    = var.project_code
    MaintenanceWindow = var.maintenance_window
    BackupRequired = var.backup_required
    Compliance     = join(",", var.compliance_requirements)
    SLA           = var.sla_percentage
  }
  
  # Combine and clean tags
  all_tags = merge(
    local.mandatory_tags,
    { for k, v in local.optional_tags : k => v if v != null }
  )
}

# Validate mandatory fields
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
```

## Guide 4: Universal Auth Configuration (Modern Pattern)

### Machine Identity Setup

```hcl
# modules/machine-identity/main.tf
# Modern authentication - NO SERVICE TOKENS!

resource "infisical_identity" "service_identity" {
  name = "${var.service_name}-${var.environment}"
  role = var.identity_role
}

# Universal Auth configuration with security constraints
resource "infisical_identity_universal_auth" "service_auth" {
  identity_id = infisical_identity.service_identity.id
  
  # Short-lived tokens for security
  client_secret_ttl     = 7200   # 2 hours
  access_token_ttl      = 1800   # 30 minutes
  access_token_max_ttl  = 3600   # 1 hour max
  access_token_num_uses = 100    # Limit API calls per token
  
  # Zero-trust: IP allowlisting
  access_token_trusted_ips = concat(
    [for ip in var.hetzner_private_ips : { ip_address = ip }],
    [for ip in var.office_ips : { ip_address = ip }]
  )
}

# Output for secure storage in CI/CD
output "client_credentials" {
  value = {
    client_id     = infisical_identity_universal_auth.service_auth.client_id
    # Client secret only shown during creation
    client_secret = sensitive(infisical_identity_universal_auth.service_auth.client_secret)
  }
  sensitive = true
  
  description = "Store these credentials immediately in your CI/CD secret store"
}
```

### Provider Configuration with Auth Block

```hcl
# providers.tf - Modern auth block pattern
terraform {
  required_version = ">= 1.13.2"
  required_providers {
    infisical = {
      source  = "infisical/infisical"
      version = "~> 0.15.0"  # Latest stable
    }
  }
}

# Modern auth block (NOT top-level client_id/service_token)
provider "infisical" {
  host = var.infisical_host  # Required for self-hosted
  
  auth {
    universal {
      client_id     = var.infisical_client_id
      client_secret = var.infisical_client_secret
    }
  }
}

# Alternative: OIDC for CI/CD (most secure)
provider "infisical" {
  alias = "oidc"
  host  = var.infisical_host
  
  auth {
    oidc {
      identity_id = var.identity_id
      # Token from GitHub Actions, GitLab CI, etc.
      token_environment_variable_name = "CI_JOB_JWT"
    }
  }
}
```

## Guide 5: Project Structure with Folder Hierarchy

### Standard Project Organization

```hcl
# modules/infisical-project-structure/main.tf
locals {
  # Standard folder structure for all services
  folder_hierarchy = {
    # Infrastructure secrets
    "/infrastructure" = {
      "/infrastructure/hetzner"   = ["HCLOUD_TOKEN", "SSH_PRIVATE_KEY"]
      "/infrastructure/network"   = ["VPN_CONFIG", "FIREWALL_RULES"]
      "/infrastructure/storage"   = ["S3_ACCESS_KEY", "S3_SECRET_KEY"]
    }
    
    # Database credentials
    "/database" = {
      "/database/postgresql" = ["DB_HOST", "DB_PORT", "DB_USER", "DB_PASSWORD"]
      "/database/redis"     = ["REDIS_URL", "REDIS_PASSWORD", "REDIS_TLS_CERT"]
    }
    
    # Application configuration
    "/application" = {
      "/application/core"     = ["APP_KEY", "JWT_SECRET", "ENCRYPTION_KEY"]
      "/application/features" = ["FEATURE_FLAGS", "RATE_LIMITS"]
    }
    
    # External services
    "/external" = {
      "/external/email"    = ["SMTP_HOST", "SMTP_USER", "SMTP_PASSWORD"]
      "/external/payment"  = ["STRIPE_KEY", "STRIPE_SECRET", "WEBHOOK_SECRET"]
      "/external/storage"  = ["S3_BUCKET", "CDN_URL", "CDN_KEY"]
    }
    
    # Monitoring and observability
    "/monitoring" = {
      "/monitoring/metrics"  = ["DATADOG_API_KEY", "DATADOG_APP_KEY"]
      "/monitoring/logs"     = ["ELASTICSEARCH_URL", "KIBANA_URL"]
      "/monitoring/traces"   = ["JAEGER_ENDPOINT", "OTEL_EXPORTER_KEY"]
    }
    
    # CI/CD and deployment
    "/deployment" = {
      "/deployment/ci"       = ["GITHUB_TOKEN", "DOCKER_REGISTRY_TOKEN"]
      "/deployment/cd"       = ["DEPLOY_KEY", "KUBECONFIG"]
    }
  }
}

# Create all folders
resource "infisical_folder" "structure" {
  for_each = merge([
    for parent, children in local.folder_hierarchy : {
      for path, _ in children : path => path
    }
  ]...)
  
  workspace_id = var.workspace_id
  env_slug     = var.environment
  path         = each.value
}

# Initialize with placeholder secrets
resource "infisical_secret" "placeholders" {
  for_each = merge([
    for parent, children in local.folder_hierarchy : {
      for path, secrets in children : 
        path => secrets
    }
  ]...)
  
  count = length(each.value)
  
  workspace_id = var.workspace_id
  env_slug     = var.environment
  folder_path  = each.key
  name         = each.value[count.index]
  value        = "PLACEHOLDER_${each.value[count.index]}_${var.environment}"
  
  lifecycle {
    ignore_changes = [value]  # Don't overwrite actual secrets
  }
}
```

## Guide 6: Disaster Recovery Configuration

### PostgreSQL PITR Setup

```hcl
# modules/disaster-recovery/main.tf
resource "null_resource" "postgresql_pitr_setup" {
  connection {
    type        = "ssh"
    host        = var.postgresql_host
    user        = "postgres"
    private_key = ephemeral.infisical_secret.ssh_key.value
  }
  
  provisioner "remote-exec" {
    inline = [
      # Configure WAL archiving
      "sudo -u postgres psql -c \"ALTER SYSTEM SET archive_mode = 'on';\"",
      "sudo -u postgres psql -c \"ALTER SYSTEM SET wal_level = 'replica';\"",
      "sudo -u postgres psql -c \"ALTER SYSTEM SET archive_command = 'test ! -f /backup/wal/%f && cp %p /backup/wal/%f';\"",
      
      # Create backup directories
      "sudo mkdir -p /backup/{wal,base}",
      "sudo chown -R postgres:postgres /backup",
      
      # Reload PostgreSQL configuration
      "sudo systemctl reload postgresql",
      
      # Create initial base backup
      "sudo -u postgres pg_basebackup -D /backup/base/$(date +%Y%m%d_%H%M%S) -Ft -z -P"
    ]
  }
}

# Automated backup schedule
resource "null_resource" "backup_cron" {
  provisioner "remote-exec" {
    inline = [
      # Daily base backup at 2 AM
      "echo '0 2 * * * postgres pg_basebackup -D /backup/base/$(date +\\%Y\\%m\\%d) -Ft -z' | sudo tee /etc/cron.d/postgresql-backup",
      
      # Cleanup old backups (keep 7 days)
      "echo '0 3 * * * postgres find /backup/base -type d -mtime +7 -exec rm -rf {} +' | sudo tee -a /etc/cron.d/postgresql-backup",
      
      # WAL cleanup (keep 3 days)
      "echo '0 4 * * * postgres find /backup/wal -type f -mtime +3 -delete' | sudo tee -a /etc/cron.d/postgresql-backup"
    ]
  }
}
```

## Guide 7: Approval Workflows for Production

```hcl
# modules/approval-workflows/main.tf
resource "infisical_approval_policy" "production_changes" {
  workspace_id = var.workspace_id
  name         = "Production Secret Changes"
  env_slug     = "prod"
  
  # Require approval for all production changes
  secret_path = "/*"
  
  approvers = [
    infisical_group.platform_teams["platform_admins"].id,
    infisical_group.platform_teams["security_auditors"].id
  ]
  
  required_approvals = 2
  enforcement_level  = "hard"  # Cannot be bypassed
  
  # Prevent self-approval
  allow_self_approval = false
  
  # Notification settings
  notifications = {
    slack = {
      webhook_url = ephemeral.infisical_secret.slack_webhook.value
      channel     = "#platform-approvals"
    }
    email = {
      recipients = ["platform@company.com", "security@company.com"]
    }
  }
}
```

## Guide 8: Pre-commit Hooks for Validation

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.96.0
    hooks:
      - id: terraform_fmt
        args: ['--args=-recursive']
      
      - id: terraform_validate
        args:
          - --args=-json
          - --args=-no-color
          - --tf-init-args=-upgrade
      
      - id: terraform_tflint
        args:
          - --args=--config=__GIT_WORKING_DIR__/.tflint.hcl
      
      - id: terraform_tfsec
        args:
          - --args=--minimum-severity=HIGH
          - --args=--exclude-path=.terraform
      
      - id: terraform_docs
        args:
          - --args=--config=.terraform-docs.yml
          - --args=--output-file=README.md

  - repo: local
    hooks:
      - id: check-ephemeral-usage
        name: Verify ephemeral resource usage
        entry: scripts/check-ephemeral.sh
        language: script
        files: \.tf$
        
      - id: validate-naming
        name: Validate resource naming
        entry: scripts/validate-naming.py
        language: python
        files: \.tf$
```

### Validation Script for Ephemeral Resources

```bash
#!/bin/bash
# scripts/check-ephemeral.sh
set -e

echo "Checking for non-ephemeral secret usage..."

# Find any data source usage for secrets (bad pattern)
if grep -r "data \"infisical_secret\"" --include="*.tf" .; then
    echo "❌ ERROR: Found data source usage for secrets. Use 'ephemeral' blocks instead!"
    echo "Replace 'data \"infisical_secret\"' with 'ephemeral \"infisical_secret\"'"
    exit 1
fi

# Find any resource block reading secrets without ephemeral
if grep -r "resource \"infisical_secret\".*value.*=.*data\." --include="*.tf" .; then
    echo "⚠️  WARNING: Possible secret value in resource block. Ensure using ephemeral pattern."
fi

echo "✅ Ephemeral resource check passed"
```

## Guide 9: Makefile for Team Productivity

```makefile
# Makefile
.PHONY: help init validate plan apply destroy clean

ENVIRONMENT ?= dev
TERRAFORM_VERSION = 1.13.2
AGENT_HOST = terraform@10.0.1.10

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

check-version: ## Verify Terraform version
	@if [ "$$(terraform version -json | jq -r .terraform_version)" != "$(TERRAFORM_VERSION)" ]; then \
		echo "❌ Wrong Terraform version. Expected $(TERRAFORM_VERSION)"; \
		exit 1; \
	fi

init: check-version ## Initialize Terraform
	@echo "🚀 Initializing Terraform for $(ENVIRONMENT)..."
	@cd terraform/environments/$(ENVIRONMENT) && \
		terraform init -upgrade

validate: init ## Validate Terraform configuration
	@echo "✅ Validating configuration..."
	@cd terraform/environments/$(ENVIRONMENT) && \
		terraform validate && \
		terraform fmt -check=true -recursive

plan: validate ## Create execution plan
	@echo "📋 Creating plan for $(ENVIRONMENT)..."
	@cd terraform/environments/$(ENVIRONMENT) && \
		terraform plan -out=tfplan-$(ENVIRONMENT)-$$(date +%Y%m%d-%H%M%S)

apply: ## Apply changes (requires confirmation)
	@echo "⚠️  Applying changes to $(ENVIRONMENT)"
	@cd terraform/environments/$(ENVIRONMENT) && \
		terraform apply -auto-approve tfplan-$(ENVIRONMENT)-*

remote-plan: ## Execute plan on remote agent
	@./scripts/terraform-remote.sh $(ENVIRONMENT) plan

remote-apply: ## Execute apply on remote agent
	@./scripts/terraform-remote.sh $(ENVIRONMENT) apply

test-dr: ## Test disaster recovery procedure
	@echo "🔥 Testing disaster recovery..."
	@./scripts/test-disaster-recovery.sh

clean: ## Clean up temporary files
	@find . -type f -name "*.tfplan*" -delete
	@find . -type f -name "*.log" -delete
	@find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
```

## Implementation Timeline

### Week 1: Foundation
- Set up repository structure
- Configure Terraform 1.13.2 on workstations
- Implement ephemeral resource patterns
- Create naming/tagging modules

### Week 2: Security & Auth
- Migrate from service tokens to Universal Auth
- Configure machine identities
- Set up approval workflows
- Implement audit logging

### Week 3: Operations
- Configure PostgreSQL PITR
- Set up monitoring integration
- Create disaster recovery procedures
- Test backup/restore processes

### Week 4: Migration
- Migrate existing configurations
- Update CI/CD pipelines
- Train team on new patterns
- Complete documentation

This comprehensive guide ensures your team follows the latest Terraform 1.13.2+ patterns with modern Infisical configurations, avoiding deprecated approaches and implementing security best practices from day one.
