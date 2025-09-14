# Immutable Audit & Log Signing

This repo ships tamper-evident decision logs by signing each decision and chaining records.

## Why

Item 11 (Immutable Audit) requires that we can prove what policy decision was made and detect tampering. We achieve this by:
- Emitting structured JSON decision logs from OPA.
- Adding an HMAC-SHA256 signature of each decision’s canonical JSON.
- Maintaining a hash chain across records to detect reordering or deletion.
- Storing logs in an append-only/WORM-capable backend.

## Enable Decision Logs

- OPA config writes decisions to a local file (see `config/decision-log.yaml` plugin `decision_logger.output_path`).

## Sign Logs

1) Export a signing key (keep secret, rotate periodically):
```bash
export DECISION_LOG_SIGNING_KEY="<strong-random-secret>"
```

2) Sign and forward logs:
```bash
./scripts/decision-log-signer.sh /var/log/opa/decisions.log > decisions.signed.jsonl
# optionally ship to your log sink with object lock enabled (e.g., S3)
```

Each record gets two fields:
- `signature`: HMAC-SHA256 of the canonical JSON
- `chain_hash`: SHA256 over `prev_chain_hash + canonical JSON`

## Verify Logs

```bash
export DECISION_LOG_SIGNING_KEY="<same-secret>"
./scripts/verify-decision-log.sh decisions.signed.jsonl
```

## Storage (Append-Only)

- Use WORM-capable storage:
  - S3 with Object Lock (compliance or governance mode)
  - Elastic with ILM and write-only API keys (plus periodic export to WORM)
  - Immutable archives (e.g., WORM storage appliance)

## Operational Notes

- Rotate keys and maintain a mapping (key id → time range). Include `key_id` in signed records if running multiple keys.
- Monitor signer pipeline health; fail closed where appropriate.
- Consider enabling TLS/mTLS to transport logs and minimize exposure.

