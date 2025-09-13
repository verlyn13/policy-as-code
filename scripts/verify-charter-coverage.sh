#!/usr/bin/env bash
set -euo pipefail

# Verify canonical decision contract packages exist.
# Required canonical paths (by Charter):
#  - data.charter.article_i.integrity.allow
#  - data.charter.article_ii.capital.allow
#  - data.charter.article_iii.entity.allow

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
POLICY_DIR="$ROOT_DIR/policies"

missing=0

require_pkg() {
  local pkg="$1"
  if ! grep -R "^package[ ]\+${pkg//./\\.}\b" "$POLICY_DIR" --include "*.rego" >/dev/null 2>&1; then
    echo "ERROR: Missing package implementation: $pkg" >&2
    missing=1
  fi
}

require_pkg "charter.article_i.integrity"
require_pkg "charter.article_ii.capital"
require_pkg "charter.article_iii.entity"

if [ "$missing" -ne 0 ]; then
  echo "\nCharter decision contracts are missing. Define the packages above and expose an 'allow' decision." >&2
  exit 1
fi

echo "✓ Charter decision contract packages present"
