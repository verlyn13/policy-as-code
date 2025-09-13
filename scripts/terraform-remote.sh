#!/bin/bash
set -euo pipefail

REMOTE_HOST="${TF_REMOTE_AGENT:-terraform@your-hetzner-agent}"
WORKSPACE_DIR="${TF_WORKSPACE_DIR:-/opt/terraform-agent/workspace}"
ENVIRONMENT="${1:-dev}"
COMMAND="${2:-plan}"
INFISICAL_HOST="${INFISICAL_HOST:-https://secrets.jefahnierocks.com}"

# Color output for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}Executing Terraform ${COMMAND} for ${ENVIRONMENT} environment${NC}"
echo -e "${GREEN}Infisical host: ${INFISICAL_HOST}${NC}"

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
         export INFISICAL_HOST=${INFISICAL_HOST} && \
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
            export INFISICAL_HOST=${INFISICAL_HOST} && \
            terraform plan -out=tfplan-${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S)"
        ;;
    "apply")
        echo -e "${RED}Applying changes to ${ENVIRONMENT}${NC}"
        read -p "Are you sure? (yes/no): " confirm
        if [[ "$confirm" == "yes" ]]; then
            ssh "${REMOTE_HOST}" "cd ${WORKSPACE_DIR}/terraform/environments/${ENVIRONMENT} && \
                export INFISICAL_HOST=${INFISICAL_HOST} && \
                terraform apply -auto-approve tfplan-${ENVIRONMENT}-*"
        fi
        ;;
    *)
        echo "Usage: $0 <environment> <init|plan|apply>"
        exit 1
        ;;
esac