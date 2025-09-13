## Summary
- What does this change do and why?

## Charter Alignment
- Affected articles/sections (e.g., Article I – Integrity, Article II – Capital):
- Decision paths touched (e.g., `data.charter.article_i.integrity.allow`):

## Validation
- [ ] `make fmt` (or `opa fmt --diff`) is clean
- [ ] `make test` passes (attach coverage if relevant)
- [ ] `opa check policies/ --strict` passes
- [ ] Charter decision contracts updated / verified

## Performance (if policy logic changed)
- Benchmarks run: `make benchmark` or domain-specific
- Budgets respected (critical P95 ≤ 20ms; standard ≤ 50ms; complex ≤ 100ms)

## Security / Bundle
- [ ] Bundle build validated (`make bundle`)
- [ ] If signing enabled, bundle signing/verification steps documented

## Screenshots / Logs
Attach relevant `opa eval` outputs, coverage summaries, or benchmark snippets.

## Follow-ups
Schemas, migration notes, or deprecation plans (if applicable).
