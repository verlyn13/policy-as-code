#!/usr/bin/env bash
# Helper script to retrieve GitHub Secrets from gopass
# Usage: ./scripts/get-github-secrets.sh

set -e

echo "📋 GitHub Secrets for policy-as-code repository"
echo "================================================"
echo ""
echo "Copy these values to your GitHub repository secrets:"
echo "(Settings → Secrets and variables → Actions → New repository secret)"
echo ""

# Set gopass password if available
export GOPASS_AGE_PASSWORD="${GOPASS_AGE_PASSWORD:-escapable diameter silk discover}"

echo "CHARTER_SIGNING_KEY_B64:"
echo "------------------------"
gopass show -o github/policy-as-code/CHARTER_SIGNING_KEY_B64 2>/dev/null || echo "Not found in gopass"
echo ""

echo "CHARTER_VERIFY_KEY_B64:"
echo "-----------------------"
gopass show -o github/policy-as-code/CHARTER_VERIFY_KEY_B64 2>/dev/null || echo "Not found in gopass"
echo ""

echo "✅ Public key is available at: docs/keys/charter-verify.pem"
echo "⚠️  Private key is stored securely in gopass at: policy-as-code/charter-signing-key"