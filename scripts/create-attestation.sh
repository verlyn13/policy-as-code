#!/usr/bin/env bash
set -euo pipefail

VERSION=${1:?"Usage: $0 <version>"}
SIGNED_DIR="build/bundles"
BUNDLE_FILE="charter-policies-${VERSION}-signed.tar.gz"

approvers=$(git log -1 --pretty=format:'%an <%ae>' | jq -R -s -c 'split("\n")[:-1]')
pr_number=$(git log -1 --grep="Merge pull request" --pretty=format:'%s' | grep -oE '#[0-9]+' | tr -d '#')

cat <<EOF
{
  "version": "${VERSION}",
  "bundle": "${BUNDLE_FILE}",
  "git": {
    "commit": "$(git rev-parse HEAD)",
    "branch": "$(git rev-parse --abbrev-ref HEAD)",
    "tag": "$(git describe --tags --always)"
  },
  "build": {
    "timestamp": "$(date -Iseconds)",
    "builder": "$(whoami)@$(hostname)",
    "opa_version": "$(opa version | awk '/Version:/ {print $2}')"
  },
  "approvals": {
    "pr_number": "${pr_number:-direct-commit}",
    "approvers": ${approvers:-[]}
  },
  "charter": {
    "version": "1.0",
    "articles_present": $(find policies/charter -type d -maxdepth 2 -mindepth 2 -printf "%f\n" 2>/dev/null | jq -R -s -c 'split("\n")[:-1]')
  },
  "integrity": {
    "bundle_hash": "$(sha256sum "${SIGNED_DIR}/${BUNDLE_FILE}" 2>/dev/null | cut -d' ' -f1)",
    "policies_hash": "$(find policies -type f -name '*.rego' -exec sha256sum {} \; | sort | sha256sum | cut -d' ' -f1)"
  }
}
EOF
