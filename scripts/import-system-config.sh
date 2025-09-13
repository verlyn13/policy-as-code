#!/bin/bash
# Import existing system configuration from system-setup repository

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SYSTEM_SETUP_DIR="${SYSTEM_SETUP_DIR:-${PROJECT_ROOT}/../system-setup}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}System Configuration Import Tool${NC}"
echo "================================="

# Check if system-setup directory exists
if [ ! -d "$SYSTEM_SETUP_DIR" ]; then
    echo -e "${RED}Error: system-setup directory not found at $SYSTEM_SETUP_DIR${NC}"
    exit 1
fi

# Function to import package manifests
import_packages() {
    echo -e "\n${YELLOW}Importing package manifests...${NC}"
    
    mkdir -p "${PROJECT_ROOT}/system/packages/manifests"
    
    # Convert DNF manifests to YAML
    for manifest in "$SYSTEM_SETUP_DIR"/manifests/dnf*.txt; do
        if [ -f "$manifest" ]; then
            basename=$(basename "$manifest" .txt)
            output="${PROJECT_ROOT}/system/packages/manifests/${basename}.yaml"
            
            echo "packages:" > "$output"
            while IFS= read -r package || [ -n "$package" ]; do
                # Skip comments and empty lines
                [[ "$package" =~ ^#.*$ ]] && continue
                [[ -z "$package" ]] && continue
                
                echo "  - name: $package" >> "$output"
                echo "    type: system" >> "$output"
            done < "$manifest"
            
            echo -e "  ${GREEN}✓${NC} Converted $basename"
        fi
    done
    
    # Import Flatpak manifest
    if [ -f "$SYSTEM_SETUP_DIR/manifests/flatpak.txt" ]; then
        output="${PROJECT_ROOT}/system/packages/manifests/flatpak.yaml"
        echo "packages:" > "$output"
        while IFS= read -r package || [ -n "$package" ]; do
            [[ "$package" =~ ^#.*$ ]] && continue
            [[ -z "$package" ]] && continue
            
            echo "  - name: $package" >> "$output"
            echo "    type: flatpak" >> "$output"
        done < "$SYSTEM_SETUP_DIR/manifests/flatpak.txt"
        
        echo -e "  ${GREEN}✓${NC} Converted flatpak manifest"
    fi
}

# Function to import dotfiles configuration
import_dotfiles() {
    echo -e "\n${YELLOW}Importing dotfiles configuration...${NC}"
    
    mkdir -p "${PROJECT_ROOT}/user/dotfiles/templates"
    
    # Import key dotfiles as templates
    dotfiles=(
        "dot_config/fish/config.fish"
        "dot_config/starship.toml"
        "dot_gitconfig"
        "dot_config/mise/config.toml"
    )
    
    for dotfile in "${dotfiles[@]}"; do
        src="${SYSTEM_SETUP_DIR}/dotfiles/${dotfile}"
        if [ -f "$src" ]; then
            filename=$(basename "$dotfile" | sed 's/^dot_//')
            dest="${PROJECT_ROOT}/user/dotfiles/templates/${filename}.j2"
            
            # Copy and convert to Jinja2 template
            cp "$src" "$dest"
            
            # Add template markers for common variables
            sed -i 's/verlyn13/{{ username }}/g' "$dest"
            sed -i 's|/home/verlyn13|{{ home_dir }}|g' "$dest"
            
            echo -e "  ${GREEN}✓${NC} Imported $filename as template"
        fi
    done
}

# Function to import AI tools configuration
import_ai_config() {
    echo -e "\n${YELLOW}Importing AI tools configuration...${NC}"
    
    mkdir -p "${PROJECT_ROOT}/ai/tools"
    
    # Create unified AI configuration
    cat > "${PROJECT_ROOT}/ai/tools/config.yaml" <<EOF
ai_tools:
  codex:
    version: "0.33.0"
    binary_path: "/usr/local/bin/codex"
    config_path: "~/.codex/config.toml"
    profiles:
      - name: speed
        model: gpt-4o-mini
        approval: on-request
      - name: depth
        model: gpt-4o
        approval: on-request
      - name: agent
        model: gpt-4o-mini
        approval: auto
    
  gemini:
    version: "0.2.2"
    binary_path: "/usr/local/bin/gem"
    config_path: "~/.config/gemini/config.json"
    models:
      - gemini-2.5-flash
      - gemini-2.5-pro
    features:
      - web-search
      - file-operations
    
  claude:
    version: "1.0.98"
    binary_path: "/usr/local/bin/claude"
    config_path: "~/.config/claude/config.json"
    models:
      - claude-sonnet-4
      - claude-opus-4.1
    mcp_servers:
      - filesystem
      - github
      - memory-bank
      - brave-search

secrets:
  storage: gopass
  paths:
    openai: development/openai/api-key
    anthropic: development/anthropic/api-key
    gemini: google/gemini/api-key
EOF
    
    echo -e "  ${GREEN}✓${NC} Created unified AI tools configuration"
}

# Function to import bootstrap scripts as Ansible tasks
import_bootstrap_scripts() {
    echo -e "\n${YELLOW}Converting bootstrap scripts to Ansible...${NC}"
    
    mkdir -p "${PROJECT_ROOT}/ansible/roles"
    
    # Map bootstrap scripts to Ansible roles
    declare -A script_to_role=(
        ["15_fish.sh"]="shell-config"
        ["30_lang.sh"]="development-tools"
        ["40_dotfiles.sh"]="dotfiles"
        ["60_ai.sh"]="ai-assistants"
        ["35_ds.sh"]="git-config"
    )
    
    for script in "${!script_to_role[@]}"; do
        role="${script_to_role[$script]}"
        script_path="${SYSTEM_SETUP_DIR}/bootstrap/${script}"
        
        if [ -f "$script_path" ]; then
            role_dir="${PROJECT_ROOT}/ansible/roles/${role}"
            mkdir -p "${role_dir}/tasks" "${role_dir}/defaults"
            
            # Create main task file
            cat > "${role_dir}/tasks/main.yml" <<EOF
---
# Converted from bootstrap/${script}
# TODO: Review and adapt these tasks

- name: ${role} configuration
  debug:
    msg: "Implement tasks from ${script}"

# Add actual tasks here based on script content
EOF
            
            echo -e "  ${GREEN}✓${NC} Created role skeleton for $role"
        fi
    done
}

# Function to create migration plan
create_migration_plan() {
    echo -e "\n${YELLOW}Creating migration plan...${NC}"
    
    cat > "${PROJECT_ROOT}/MIGRATION-PLAN.md" <<EOF
# System Configuration Migration Plan

## Overview
This document outlines the migration from bootstrap scripts to Policy as Code.

## Completed Imports
- Package manifests converted to YAML
- Dotfiles converted to Jinja2 templates
- AI tools configuration unified
- Bootstrap scripts mapped to Ansible roles

## Next Steps

### 1. Complete Ansible Role Implementation
- [ ] Review generated role skeletons
- [ ] Implement actual tasks from bootstrap scripts
- [ ] Add variable definitions
- [ ] Create role documentation

### 2. Test Infrastructure
- [ ] Set up test VMs with Fedora 42
- [ ] Test development workstation profile
- [ ] Test server profiles
- [ ] Validate idempotency

### 3. Terraform Integration
- [ ] Create Terraform resources for local provisioning
- [ ] Integrate with Ansible provisioner
- [ ] Add state management

### 4. Policy Implementation
- [ ] Write OPA policies for each component
- [ ] Add compliance checks
- [ ] Create validation tests

### 5. Documentation
- [ ] Update README with new workflow
- [ ] Create user guides
- [ ] Document troubleshooting

## File Mappings

| Original | Policy as Code Location |
|----------|------------------------|
| bootstrap/*.sh | ansible/roles/*/tasks/main.yml |
| manifests/*.txt | system/packages/manifests/*.yaml |
| dotfiles/* | user/dotfiles/templates/*.j2 |
| CLAUDE.md | ai/tools/config.yaml |

## Testing Checklist
- [ ] Fresh Fedora 42 installation
- [ ] Existing system update
- [ ] Multi-system deployment
- [ ] Rollback procedures
- [ ] Disaster recovery

## Timeline
- Week 1: Complete Ansible roles
- Week 2: Testing and validation
- Week 3: Documentation and training
- Week 4: Production migration
EOF
    
    echo -e "  ${GREEN}✓${NC} Created migration plan"
}

# Main execution
main() {
    echo -e "\nImporting from: ${SYSTEM_SETUP_DIR}"
    echo -e "Target directory: ${PROJECT_ROOT}\n"
    
    import_packages
    import_dotfiles
    import_ai_config
    import_bootstrap_scripts
    create_migration_plan
    
    echo -e "\n${GREEN}Import completed successfully!${NC}"
    echo -e "\nNext steps:"
    echo "1. Review imported configurations in system/, user/, and ai/ directories"
    echo "2. Complete Ansible role implementations"
    echo "3. Test with: ansible-playbook -i ansible/inventories/systems.yml ansible/playbooks/apply-profile.yml"
    echo "4. See MIGRATION-PLAN.md for detailed next steps"
}

main "$@"