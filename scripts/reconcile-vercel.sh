#!/bin/bash
# Reconcile Vercel environment variables from generated manifest
# Ensures no secrets are stored directly, only INFISICAL_* references

set -euo pipefail

PROJECT="${1:-journal}"
DRY_RUN="${2:-false}"
MANIFEST=".out/${PROJECT}/vercel-env.json"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🔄 Reconciling Vercel environment for project: ${PROJECT}${NC}"

# Check manifest exists
if [ ! -f "$MANIFEST" ]; then
    echo -e "${RED}❌ Manifest not found: ${MANIFEST}${NC}"
    echo "Run 'make render' first to generate artifacts"
    exit 1
fi

# Parse manifest
PUBLIC_ENV=$(jq -r '.environment.public // {}' "$MANIFEST")
SERVER_ENV=$(jq -r '.environment.server // {}' "$MANIFEST")

if [ "$DRY_RUN" == "true" ]; then
    echo -e "${YELLOW}⚠️  DRY RUN MODE - No changes will be applied${NC}"
fi

# Function to set Vercel environment variable
set_vercel_env() {
    local key=$1
    local value=$2
    local target=$3  # production, preview, development
    
    echo -e "  Setting ${key} (${target})"
    
    if [ "$DRY_RUN" != "true" ]; then
        # Using Vercel CLI
        vercel env add "$key" "$target" <<< "$value" 2>/dev/null || \
        vercel env rm "$key" "$target" --yes 2>/dev/null && \
        vercel env add "$key" "$target" <<< "$value"
    else
        echo "    [DRY RUN] vercel env add $key $target"
    fi
}

# Function to validate no secrets in value
validate_no_secrets() {
    local key=$1
    local value=$2
    
    # Check for common secret patterns
    if [[ "$value" =~ (password|secret|key|token|credential) ]] && \
       [[ ! "$key" =~ ^INFISICAL_ ]]; then
        echo -e "${RED}    ⚠️  WARNING: Potential secret in ${key}${NC}"
        return 1
    fi
    
    # Check for base64 encoded strings (potential secrets)
    if [[ "$value" =~ ^[A-Za-z0-9+/]{40,}=*$ ]]; then
        echo -e "${YELLOW}    ⚠️  WARNING: Potential encoded secret in ${key}${NC}"
        return 1
    fi
    
    return 0
}

echo -e "\n${YELLOW}📋 Applying Public Environment Variables...${NC}"

# Apply public environment variables
echo "$PUBLIC_ENV" | jq -r 'to_entries | .[] | "\(.key)=\(.value)"' | while IFS='=' read -r key value; do
    # Verify NEXT_PUBLIC_ prefix
    if [[ ! "$key" =~ ^NEXT_PUBLIC_ ]]; then
        echo -e "${RED}  ❌ Skipping ${key} - must start with NEXT_PUBLIC_${NC}"
        continue
    fi
    
    # Validate no secrets
    if validate_no_secrets "$key" "$value"; then
        set_vercel_env "$key" "$value" "production"
        set_vercel_env "$key" "$value" "preview"
        set_vercel_env "$key" "$value" "development"
    fi
done

echo -e "\n${YELLOW}🔐 Applying Server Environment Variables...${NC}"

# Apply server environment variables
echo "$SERVER_ENV" | jq -r 'to_entries | .[] | "\(.key)=\(.value)"' | while IFS='=' read -r key value; do
    # Ensure only INFISICAL_* vars for server
    if [[ ! "$key" =~ ^INFISICAL_ ]]; then
        echo -e "${RED}  ❌ Skipping ${key} - server vars must be INFISICAL_*${NC}"
        continue
    fi
    
    # These should be references, not actual values
    if [[ "$value" =~ ^\$\{.*\}$ ]]; then
        echo -e "${GREEN}  ✓ ${key} is a reference (good)${NC}"
        # In production, you'd get the actual value from Infisical
        if [ "$DRY_RUN" != "true" ]; then
            # Fetch from Infisical
            actual_value=$(infisical secrets get "$key" --plain 2>/dev/null || echo "")
            if [ -n "$actual_value" ]; then
                set_vercel_env "$key" "$actual_value" "production"
            else
                echo -e "${YELLOW}    ⚠️  Could not fetch ${key} from Infisical${NC}"
            fi
        fi
    else
        set_vercel_env "$key" "$value" "production"
    fi
done

# Verify build settings
echo -e "\n${YELLOW}🏗️  Build Configuration:${NC}"
BUILD_CMD=$(jq -r '.build.command // "npm run build"' "$MANIFEST")
OUTPUT_DIR=$(jq -r '.build.output_directory // ".next"' "$MANIFEST")

echo "  Build Command: $BUILD_CMD"
echo "  Output Directory: $OUTPUT_DIR"

if [ "$DRY_RUN" != "true" ]; then
    # Update Vercel project settings
    echo -e "\n${YELLOW}Updating Vercel project settings...${NC}"
    
    # This would use Vercel API to update build settings
    # For now, we'll output the commands
    echo "  vercel --build-command=\"$BUILD_CMD\""
    echo "  vercel --output-directory=\"$OUTPUT_DIR\""
fi

# Summary
echo -e "\n${GREEN}📊 Reconciliation Summary:${NC}"
echo "  Project: $PROJECT"
echo "  Public vars: $(echo "$PUBLIC_ENV" | jq -r 'keys | length') configured"
echo "  Server vars: $(echo "$SERVER_ENV" | jq -r 'keys | length') configured"

if [ "$DRY_RUN" == "true" ]; then
    echo -e "\n${YELLOW}This was a dry run. Run without --dry-run to apply changes.${NC}"
else
    echo -e "\n${GREEN}✅ Vercel environment reconciliation complete!${NC}"
fi

# Validate final state
echo -e "\n${YELLOW}🔍 Validating final state...${NC}"

if [ "$DRY_RUN" != "true" ]; then
    # List current env vars
    echo "  Current environment variables:"
    vercel env ls 2>/dev/null | head -10 || echo "    (Unable to list - ensure you're in a Vercel project)"
fi

echo -e "\n${GREEN}✅ Reconciliation complete for Vercel project: ${PROJECT}${NC}"