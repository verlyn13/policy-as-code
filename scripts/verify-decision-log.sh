#!/usr/bin/env bash
set -euo pipefail

# Verify HMAC signatures on signed OPA decision logs.
# Usage: DECISION_LOG_SIGNING_KEY=secret ./scripts/verify-decision-log.sh decisions.signed.jsonl

SIGNED_FILE=${1:?"Usage: $0 <signed.jsonl>"}
KEY=${DECISION_LOG_SIGNING_KEY:-}

if [[ -z "${KEY}" ]]; then
  echo "DECISION_LOG_SIGNING_KEY is required" >&2
  exit 1
fi

ok=0; fail=0
prev_chain=""
while IFS= read -r line; do
  sig=$(echo "$line" | jq -r '.signature')
  chain=$(echo "$line" | jq -r '.chain_hash')
  content=$(echo "$line" | jq 'del(.signature, .chain_hash)')
  canon=$(echo "$content" | jq -c '.')

  vsig=$(printf '%s' "$canon" | openssl dgst -sha256 -hmac "$KEY" -binary | base64 -w0)
  chain_input="${prev_chain}${canon}"
  vchain=$(printf '%s' "$chain_input" | openssl dgst -sha256 -binary | base64 -w0)
  if [[ "$vsig" == "$sig" && "$vchain" == "$chain" ]]; then
    ok=$((ok+1))
    prev_chain="$chain"
  else
    fail=$((fail+1))
    echo "Verification failed for: $canon" >&2
  fi
done < "$SIGNED_FILE"

echo "Verified: $ok, Failed: $fail"
[[ $fail -eq 0 ]]

