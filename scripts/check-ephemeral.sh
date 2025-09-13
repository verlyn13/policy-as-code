#!/bin/bash
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