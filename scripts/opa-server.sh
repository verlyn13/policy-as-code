#!/bin/bash
# OPA Server Startup Script with Production Configuration

set -e

OPA_VERSION="v1.7.1"
CONFIG_FILE="config/config.yaml"
BUNDLE_DIR="bundles"
PORT="${OPA_PORT:-8181}"
LOG_LEVEL="${OPA_LOG_LEVEL:-info}"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Starting OPA Server${NC}"
echo "=================="

# Check OPA installation
if ! command -v opa &> /dev/null; then
    echo -e "${RED}Error: OPA is not installed${NC}"
    echo "Please run: make install"
    exit 1
fi

# Verify OPA version
INSTALLED_VERSION=$(opa version --format json | jq -r .Version)
echo "OPA Version: $INSTALLED_VERSION"

# Build bundle if needed
if [ ! -f "$BUNDLE_DIR/bundle.tar.gz" ] || [ "$1" == "--build" ]; then
    echo -e "${YELLOW}Building policy bundle...${NC}"
    opa build \
        -b policies/ \
        -b data/ \
        -b .manifest \
        -o "$BUNDLE_DIR/bundle.tar.gz"
    echo -e "${GREEN}✓ Bundle created${NC}"
fi

# Set environment variables for decision logging
export DECISION_LOG_URL="${DECISION_LOG_URL:-http://localhost:9200/decisions}"
export DECISION_LOG_TOKEN="${DECISION_LOG_TOKEN:-dummy-token}"
export HOSTNAME="${HOSTNAME:-$(hostname)}"
export ENVIRONMENT="${ENVIRONMENT:-development}"

# Start OPA server
echo -e "${GREEN}Starting OPA server on port $PORT...${NC}"
echo "Configuration: $CONFIG_FILE"
echo "Bundle: $BUNDLE_DIR/bundle.tar.gz"
echo "Log Level: $LOG_LEVEL"
echo ""

# Run OPA with appropriate configuration
if [ "$ENVIRONMENT" == "production" ]; then
    # Production mode with decision logging and monitoring
    exec opa run \
        --server \
        --config-file="$CONFIG_FILE" \
        --addr=":$PORT" \
        --log-level="$LOG_LEVEL" \
        --bundle="$BUNDLE_DIR/bundle.tar.gz" \
        --set="decision_logs.console=false" \
        --set="status.console=false"
else
    # Development mode with console output
    exec opa run \
        --server \
        --addr=":$PORT" \
        --log-level="$LOG_LEVEL" \
        --bundle="$BUNDLE_DIR/bundle.tar.gz" \
        --set="decision_logs.console=true" \
        --set="status.console=true" \
        --watch
fi