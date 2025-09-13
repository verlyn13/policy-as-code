# Policy as Code Implementation Guide

## Overview

This repository implements a modern Terraform 1.13.2+ infrastructure management system with:
- Ephemeral secrets management (no secrets in state)
- Unified compute abstraction (servers and containers)
- OPA policy enforcement
- Disaster recovery automation

## Quick Start

```bash
# 1. Set up environment
source .envrc

# 2. Initialize Terraform for dev environment
make init ENVIRONMENT=dev

# 3. Plan changes
make plan

# 4. Apply changes
make apply
```

## Repository Structure

```
.
├── terraform/                 # Terraform configurations
│   ├── environments/         # Environment-specific configs
│   │   ├── dev/
│   │   ├── stg/
│   │   └── prod/
│   ├── modules/              # Reusable modules
│   │   ├── naming-standards/
│   │   ├── tagging-policy/
│   │   └── unified-compute/
│   └── config/               # Shared configuration
├── policies/                 # OPA policies
│   ├── kubernetes/
│   ├── terraform/
│   ├── docker/
│   └── github/
├── scripts/                  # Utility scripts
├── Makefile                  # Task automation
└── .pre-commit-config.yaml  # Pre-commit hooks
```

## Key Features

### 1. Ephemeral Secrets Management

All secrets are fetched ephemerally and never stored in Terraform state:

```hcl
ephemeral "infisical_secret" "db_password" {
  name         = "DB_PASSWORD"
  env_slug     = var.environment
  workspace_id = var.infisical_workspace_id
  folder_path  = "/database/postgresql"
}
```

### 2. Unified Compute Module

Abstract infrastructure provisioning across servers and containers:

```hcl
module "compute" {
  source = "../../modules/unified-compute"
  
  compute_type    = "server"  # or "container"
  workload_name   = "api"
  environment     = "dev"
  # ... additional configuration
}
```

### 3. Naming Standards

Enforced naming convention: `<type>-<workload>-<env>-<region>-<instance>`

Example: `hcs-api-dev-hel1-001`

### 4. Tagging Policy

Mandatory tags for all resources:
- Owner
- CostCenter
- Environment
- ApplicationId
- DataSensitivity

## Configuration

### Infisical Host

The Infisical host is configurable via:
1. Environment variable: `INFISICAL_HOST`
2. Makefile variable: `make plan INFISICAL_HOST=https://your-host.com`
3. Default in variables.tf: `https://secrets.jefahnierocks.com`

### Remote Execution

For production deployments on Hetzner agents:

```bash
# Execute on remote agent
make remote-plan ENVIRONMENT=prod
make remote-apply ENVIRONMENT=prod
```

## Security Best Practices

1. **Never use data sources for secrets** - Always use ephemeral blocks
2. **Universal Auth only** - No service tokens
3. **IP allowlisting** - Restrict access by IP
4. **Short-lived tokens** - 30-minute access tokens
5. **Approval workflows** - Required for production changes

## Development Workflow

1. Create feature branch
2. Make changes
3. Run validation: `make validate`
4. Create plan: `make plan`
5. Review changes
6. Apply: `make apply`

## Pre-commit Hooks

Install pre-commit hooks:

```bash
pre-commit install
```

Hooks will:
- Format Terraform code
- Validate configuration
- Check for ephemeral resource usage
- Validate naming conventions

## Troubleshooting

### Wrong Terraform Version

```bash
# Check version
terraform version

# Install correct version (1.13.2)
wget https://releases.hashicorp.com/terraform/1.13.2/terraform_1.13.2_linux_amd64.zip
unzip terraform_1.13.2_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

### Infisical Connection Issues

Check the Infisical host configuration:
```bash
echo $INFISICAL_HOST
# Should output: https://secrets.jefahnierocks.com
```

### Clean Up

Remove all temporary files:
```bash
make clean
```

## Next Steps

- [ ] Configure Infisical workspace and credentials
- [ ] Set up OPA policies
- [ ] Configure disaster recovery procedures
- [ ] Set up CI/CD pipelines
- [ ] Configure monitoring and alerting