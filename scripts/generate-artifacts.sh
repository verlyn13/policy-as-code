#!/bin/bash
# Generate artifact files from validated intents and configs

set -euo pipefail

PROJECT="${1:-journal}"
OUTPUT_DIR=".out/${PROJECT}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Generating artifacts for project: ${PROJECT}${NC}"

# Create output directory
mkdir -p "${OUTPUT_DIR}"

# Function to generate Infisical ProjectRole YAML
generate_project_role() {
    local env=$1
    local role=$2
    
    cat > "${OUTPUT_DIR}/ProjectRole_${role}_${env}.yaml" <<EOF
apiVersion: infisical.io/v1
kind: ProjectRole
metadata:
  name: ${role}
  namespace: infisical-${PROJECT}
  environment: ${env}
spec:
  description: "Generated role for ${role} in ${env}"
  permissions:
    - resource: secrets
      action: read
      conditions:
        environment: ${env}
EOF
    
    echo -e "  ${GREEN}✓${NC} Generated ProjectRole_${role}_${env}.yaml"
}

# Function to generate Identity YAML
generate_identity() {
    local name=$1
    local type=$2
    local env=$3
    
    cat > "${OUTPUT_DIR}/identity_${name}_${env}.yaml" <<EOF
apiVersion: infisical.io/v1
kind: MachineIdentity
metadata:
  name: ${name}
  namespace: infisical-${PROJECT}
spec:
  type: ${type}
  environment: ${env}
  project: ${PROJECT}
  description: "Machine identity for ${name}"
EOF
    
    echo -e "  ${GREEN}✓${NC} Generated identity_${name}_${env}.yaml"
}

# Function to generate binding YAML
generate_binding() {
    local identity=$1
    local role=$2
    local env=$3
    local paths=$4
    
    cat > "${OUTPUT_DIR}/binding_${identity}_${role}_${env}.yaml" <<EOF
apiVersion: infisical.io/v1
kind: IdentityBinding
metadata:
  name: ${identity}-${role}-binding
  namespace: infisical-${PROJECT}
spec:
  identity: ${identity}
  role: ${role}
  environment: ${env}
  paths: ${paths}
  ttl: 3600
EOF
    
    echo -e "  ${GREEN}✓${NC} Generated binding_${identity}_${role}_${env}.yaml"
}

# Function to generate Vercel env.json
generate_vercel_env() {
    local input_file="data/platforms/vercel/${PROJECT}.yaml"
    
    if [ -f "$input_file" ]; then
        # Convert YAML to JSON and add metadata
        yq eval -o=json "$input_file" | jq '{
            project: "'${PROJECT}'",
            timestamp: now | todate,
            environment: {
                public: .public_env // {},
                server: .server_env // {}
            },
            build: {
                command: .build_command // "npm run build",
                output_directory: .output_directory // ".next"
            }
        }' > "${OUTPUT_DIR}/vercel-env.json"
        
        echo -e "  ${GREEN}✓${NC} Generated vercel-env.json"
    else
        echo -e "  ${YELLOW}⚠${NC} No Vercel config found for ${PROJECT}"
    fi
}

# Function to generate Supabase config.json
generate_supabase_config() {
    local input_file="data/platforms/supabase/${PROJECT}.yaml"
    
    if [ -f "$input_file" ]; then
        # Convert YAML to JSON with proper structure
        yq eval -o=json "$input_file" | jq '{
            project: "'${PROJECT}'",
            timestamp: now | todate,
            auth: {
                jwt_secret: .jwt_secret,
                jwt_exp: .jwt_exp,
                providers: .auth_providers // []
            },
            database: {
                rls_enforced: .rls_enforced // true,
                schema: "public"
            },
            environment: {
                public: .public_env // {}
            }
        }' > "${OUTPUT_DIR}/supabase-config.json"
        
        echo -e "  ${GREEN}✓${NC} Generated supabase-config.json"
    else
        echo -e "  ${YELLOW}⚠${NC} No Supabase config found for ${PROJECT}"
    fi
}

# Main generation logic
echo -e "\n${YELLOW}Generating Infisical artifacts...${NC}"

# Parse identities from data/infisical/${PROJECT}/identities.yaml
if [ -f "data/infisical/${PROJECT}/identities.yaml" ]; then
    # Generate for each environment
    for env in dev stg prod; do
        echo -e "\n  Environment: ${env}"
        
        # Generate project roles
        generate_project_role "$env" "runtime"
        generate_project_role "$env" "ci"
        
        # Generate identities based on the identities.yaml
        # This is simplified - in production you'd parse the YAML properly
        generate_identity "token-service" "runtime" "$env"
        generate_identity "github-actions" "ci" "$env"
        
        if [ "$env" == "prod" ]; then
            generate_identity "rotator" "security-ops-prj" "$env"
        fi
        
        # Generate bindings
        generate_binding "token-service" "runtime" "$env" "['/auth/jwt/*', '/auth/aes/*']"
        generate_binding "github-actions" "ci" "$env" "['/auth/jwt/public_jwks']"
    done
fi

echo -e "\n${YELLOW}Generating platform configs...${NC}"

# Generate Vercel config
generate_vercel_env

# Generate Supabase config
generate_supabase_config

# Generate summary manifest
echo -e "\n${YELLOW}Generating manifest...${NC}"
cat > "${OUTPUT_DIR}/manifest.json" <<EOF
{
  "project": "${PROJECT}",
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "artifacts": $(find "${OUTPUT_DIR}" -type f -name "*.yaml" -o -name "*.json" | jq -R -s 'split("\n")[:-1]')
}
EOF

echo -e "  ${GREEN}✓${NC} Generated manifest.json"

# Count artifacts
artifact_count=$(find "${OUTPUT_DIR}" -type f \( -name "*.yaml" -o -name "*.json" \) | wc -l)
echo -e "\n${GREEN}✅ Successfully generated ${artifact_count} artifacts in ${OUTPUT_DIR}${NC}"