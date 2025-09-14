#!/usr/bin/env bash
set -euo pipefail

# Sign OPA decision logs with an HMAC-SHA256 to make them tamper-evident.
# Usage: DECISION_LOG_SIGNING_KEY=secret ./scripts/decision-log-signer.sh /path/to/decisions.log > decisions.signed.jsonl

LOG_FILE=${1:-/var/log/opa/decisions.log}
KEY=${DECISION_LOG_SIGNING_KEY:-}

if [[ -z "${KEY}" ]]; then
  echo "DECISION_LOG_SIGNING_KEY is required" >&2
  exit 1
fi

if ! command -v jq >/dev/null || ! command -v openssl >/dev/null; then
  echo "Requires jq and openssl" >&2
  exit 1
fi

prev_chain=""
exec <"${LOG_FILE}"
while IFS= read -r line; do
  # Normalize JSON
  canon=$(echo "$line" | jq -c '.')
  # Compute content HMAC
  sig=$(printf '%s' "$canon" | openssl dgst -sha256 -hmac "$KEY" -binary | base64 -w0)
  # Compute chain hash (prev + current content)
  chain_input="${prev_chain}${canon}"
  chain=$(printf '%s' "$chain_input" | openssl dgst -sha256 -binary | base64 -w0)
  prev_chain="$chain"
  # Emit signed record
  echo "$canon" | jq -c --arg sig "$sig" --arg chain "$chain" '. + {signature: $sig, chain_hash: $chain}'
done

