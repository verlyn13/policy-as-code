# System Configuration Layers Architecture

## Overview

This document defines the layered architecture for integrating personal system configuration into the Policy as Code framework, creating a unified management system for both infrastructure and workstation configuration.

## Architecture Layers

### Layer 1: Base System Configuration
**Purpose**: Core OS and package management
**Scope**: System-wide configurations that require privileged access

```
system/
├── os/
│   ├── fedora/
│   │   ├── dnf-packages.yaml      # System packages manifest
│   │   ├── repos.yaml              # Repository configuration
│   │   └── kernel-params.yaml     # Kernel parameters
│   └── common/
│       ├── sysctl.yaml            # System tuning
│       └── security.yaml          # Security hardening
├── packages/
│   ├── manifests/
│   │   ├── base.yaml              # Core packages
│   │   ├── development.yaml       # Dev tools
│   │   └── ai-tools.yaml          # AI CLI tools
│   └── policies/
│       └── version-constraints.rego
```

### Layer 2: User Environment Configuration
**Purpose**: User-specific configurations and dotfiles
**Scope**: User home directory, no privileged access needed

```
user/
├── shell/
│   ├── fish/
│   │   ├── config.yaml            # Fish shell config
│   │   ├── functions.yaml         # Custom functions
│   │   └── aliases.yaml           # Aliases
│   ├── bash/
│   │   └── bashrc.yaml
│   └── common/
│       ├── environment.yaml       # Environment variables
│       └── path.yaml              # PATH configuration
├── dotfiles/
│   ├── templates/
│   │   ├── gitconfig.j2          # Git configuration
│   │   ├── starship.toml.j2      # Prompt configuration
│   │   └── mise.toml.j2          # Tool version management
│   └── policies/
│       └── dotfile-validation.rego
```

### Layer 3: Development Environment
**Purpose**: Programming language and tool configuration
**Scope**: Development tools, package managers, project templates

```
development/
├── languages/
│   ├── python/
│   │   ├── uv-config.yaml        # uv package manager
│   │   ├── ruff.yaml             # Linting config
│   │   └── pyproject.toml        # Project template
│   ├── javascript/
│   │   ├── bun-config.yaml       # Bun runtime
│   │   ├── biome.yaml            # Linting/formatting
│   │   └── package.json          # Project template
│   └── rust/
│       └── cargo-config.yaml
├── tools/
│   ├── editors/
│   │   ├── vscode.yaml           # VS Code settings
│   │   └── neovim.yaml           # Neovim config
│   └── version-management/
│       └── mise.yaml              # mise (rtx) config
└── policies/
    ├── dependency-security.rego
    └── license-compliance.rego
```

### Layer 4: AI Tools Integration
**Purpose**: AI assistant configuration and orchestration
**Scope**: API keys, model selection, project context

```
ai/
├── tools/
│   ├── codex/
│   │   ├── config.yaml           # Codex CLI config
│   │   ├── profiles.yaml         # Speed/depth profiles
│   │   └── agents.yaml           # Agent definitions
│   ├── gemini/
│   │   ├── config.yaml           # Gemini CLI config
│   │   └── search-config.yaml    # Web search settings
│   └── claude/
│       ├── config.yaml           # Claude Code config
│       └── mcp-servers.yaml      # MCP server configs
├── secrets/
│   ├── api-keys.yaml             # Encrypted API keys
│   └── auth-tokens.yaml          # Authentication tokens
├── project-templates/
│   ├── agents.md.j2              # AGENTS.md template
│   └── ai-config.yaml.j2        # Project AI config
└── policies/
    ├── api-usage-limits.rego
    └── model-selection.rego
```

### Layer 5: Secrets Management
**Purpose**: Unified secrets storage and access control
**Scope**: All sensitive configuration data

```
secrets/
├── gopass/
│   ├── config.yaml               # gopass configuration
│   ├── recipients.yaml           # Encryption recipients
│   └── structure.yaml            # Secret organization
├── infisical/
│   ├── projects.yaml             # Project definitions
│   ├── identities.yaml          # Machine identities
│   └── policies.yaml            # Access policies
└── policies/
    ├── secret-rotation.rego
    └── access-control.rego
```

### Layer 6: Observability & Monitoring
**Purpose**: System and application monitoring
**Scope**: Metrics, logs, traces, dashboards

```
observability/
├── collectors/
│   ├── otel/
│   │   └── config.yaml           # OpenTelemetry config
│   └── promtail/
│       └── config.yaml           # Log collection
├── storage/
│   ├── prometheus/
│   │   └── prometheus.yaml
│   ├── loki/
│   │   └── loki.yaml
│   └── tempo/
│       └── tempo.yaml
├── visualization/
│   ├── grafana/
│   │   ├── datasources.yaml
│   │   └── dashboards/
│   └── alerts/
│       └── rules.yaml
└── policies/
    ├── retention.rego
    └── pii-detection.rego
```

## Implementation Modules

### Terraform Modules for System Configuration

```hcl
# terraform/modules/workstation-config/main.tf
module "system_packages" {
  source = "../system-packages"
  
  manifest_path = var.package_manifest
  environment   = var.environment
}

module "dotfiles" {
  source = "../dotfiles-management"
  
  user         = var.username
  templates    = var.dotfile_templates
  backup_path  = var.backup_location
}

module "ai_tools" {
  source = "../ai-tools-setup"
  
  tools = {
    codex = {
      version = "0.33.0"
      config  = var.codex_config
    }
    gemini = {
      version = "0.2.2"
      config  = var.gemini_config
    }
    claude = {
      version = "1.0.98"
      config  = var.claude_config
    }
  }
}
```

### Ansible Playbooks for Configuration Management

```yaml
# ansible/playbooks/workstation-setup.yml
---
- name: Configure Development Workstation
  hosts: localhost
  vars_files:
    - "{{ environment }}.yml"
  
  roles:
    - role: base-system
      tags: [system]
    
    - role: development-tools
      tags: [dev]
    
    - role: ai-assistants
      tags: [ai]
    
    - role: dotfiles
      tags: [config]
    
    - role: secrets-management
      tags: [secrets]
```

### OPA Policies for Configuration Validation

```rego
# policies/system/package-validation.rego
package system.packages

deny[msg] {
  input.package.source == "unknown"
  msg := sprintf("Package %s from unknown source", [input.package.name])
}

deny[msg] {
  input.package.version == "latest"
  msg := sprintf("Package %s must specify exact version", [input.package.name])
}

# policies/ai/api-key-validation.rego
package ai.secrets

deny[msg] {
  input.api_key.provider == "openai"
  not input.api_key.encrypted
  msg := "OpenAI API key must be encrypted"
}

deny[msg] {
  input.api_key.expiry < time.now_ns()
  msg := sprintf("API key for %s has expired", [input.api_key.provider])
}
```

## Integration Points

### 1. Bootstrap to Policy as Code

```bash
# Convert bootstrap scripts to declarative configuration
./scripts/bootstrap-to-terraform.sh \
  --input ../system-setup/bootstrap/ \
  --output terraform/modules/bootstrap/

# Generate Ansible playbooks from manifests
./scripts/manifest-to-ansible.sh \
  --input ../system-setup/manifests/ \
  --output ansible/roles/packages/
```

### 2. Dotfiles to Configuration Management

```bash
# Import existing dotfiles to chezmoi templates
chezmoi add --template ~/.config/fish/config.fish
chezmoi add --template ~/.gitconfig

# Generate Terraform resources from chezmoi
./scripts/chezmoi-to-terraform.sh \
  --source ~/.local/share/chezmoi/ \
  --output terraform/modules/dotfiles/
```

### 3. AI Tools Configuration

```yaml
# ai/orchestration/workflow.yaml
workflows:
  architecture_review:
    steps:
      - tool: codex
        profile: depth
        prompt: "Review system architecture"
      
      - tool: gemini
        mode: search
        prompt: "Find best practices for {context}"
      
      - tool: claude
        mode: implement
        prompt: "Apply recommendations"
```

## Migration Strategy

### Phase 1: Assessment (Week 1)
- Inventory existing configurations
- Identify dependencies
- Map to policy framework

### Phase 2: Modularization (Week 2)
- Create Terraform modules
- Write Ansible playbooks
- Define OPA policies

### Phase 3: Testing (Week 3)
- Test on fresh Fedora 42 VM
- Validate idempotency
- Performance testing

### Phase 4: Migration (Week 4)
- Backup existing system
- Apply configuration
- Verify functionality

## Benefits of This Architecture

1. **Unified Management**: Single source of truth for both infrastructure and workstation configuration
2. **Version Control**: All configuration as code in Git
3. **Compliance**: OPA policies ensure standards are met
4. **Reproducibility**: Quickly provision new workstations
5. **Disaster Recovery**: Rapid system restoration
6. **Team Scalability**: Easy to onboard new developers
7. **Audit Trail**: Complete history of configuration changes

## Next Steps

1. Create initial module structure in this repository
2. Import package manifests from system-setup
3. Convert bootstrap scripts to Terraform/Ansible
4. Write OPA policies for validation
5. Test with a fresh Fedora 42 installation