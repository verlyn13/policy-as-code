# Repository Guidelines

These guidelines align with Open Policy Agent v1.7.1. Reference: https://v1-7-1--opa-docs.netlify.app/

## Project Structure & Module Organization
- `policies/`: Rego policies by domain (`kubernetes/`, `terraform/`, `docker/`, `github/`); shared helpers in `policies/lib/`.
- `tests/`: Policy tests (`*_test.rego`) and shared helpers (`tests/test_framework.rego`).
- `data/`: Static JSON/YAML bundled with policies.
- `examples/`: Sample inputs (e.g., `examples/kubernetes/pod-secure.json`).
- `config/`: OPA server/decision-log configs (`config.yaml`, `decision-log.yaml`).
- `bundles/`: Built artifacts (`bundle.tar.gz`) with `.manifest` (`rego_version: 1`, `roots`).
- `scripts/`: Operational helpers (`opa-server.sh`, `benchmark.sh`).

## Build, Test, and Development Commands
- `make install`: Install OPA v1.7.1; verify with `opa version`.
- `make fmt` | `make validate`: Format Rego; check formatting with `opa fmt --diff`.
- `make test` | `make test-coverage`: Run tests (verbose) with coverage.
- `make bundle` | `make inspect`: Build and inspect the bundle.
- `make server` | `make server-dev`: Start OPA (prod/dev; dev uses `--watch`).
- `make benchmark` | `make benchmark-profile`: Run performance tests; optional CPU profile.
- `make verify` | `make ci` | `make clean`: All checks, local CI, cleanup.

## Coding Style & Naming Conventions
- Use `opa fmt` (spaces; sorted imports). Rego files: kebab-case (e.g., `pod-security.rego`).
- Packages: domain.scoped (e.g., `kubernetes.admission`, `terraform.validation`).
- Include a `# METADATA` block (title, description, custom fields) at top.
- Prefer common functions in `policies/lib/` and import via `import data.lib.<module>`.
- For forward-compatibility, import `future.keywords.*` as shown in existing policies.

## Testing Guidelines
- Framework: `opa test` (no external harness required).
- Structure: `tests/<domain>/*_test.rego`; reuse `tests/test_framework.rego` assertions.
- Coverage: CI enforces ≥ 80% (`opa test policies/ tests/ --coverage`).
- Local examples: `opa eval -d policies/kubernetes/ -i examples/kubernetes/pod-secure.json "data.kubernetes.admission.allow"`.
- Include positive/negative cases and edge conditions per rule.

## Commit & Pull Request Guidelines
- Commits: Imperative, concise subject (≤72 chars). Scope by domain when useful, e.g., `kubernetes: enforce non-root`; link issues.
- PRs: Describe intent and impact, include `make test` (and `make benchmark` if changed), update docs as behavior changes.
- Required: Passing CI, `make fmt` clean, tests for new/changed logic.

## Security & Configuration Tips
- Version pin: OPA v1.7.1; bundle `.manifest` sets `rego_version: 1` and `roots` for deterministic builds.
- Configuration from `config/`; `scripts/opa-server.sh` supports `ENVIRONMENT`, `DECISION_LOG_URL`, `DECISION_LOG_TOKEN`.
- No secrets in repo; use environment variables and keep local overrides out of VCS.

## Implementation Phases (Priorities)
- Phase 1 — Trust Infrastructure: Bundle signing, decision contracts, and semantic checks (`opa check policies/ --strict`).
- Phase 2 — Operational Excellence: Enforce performance budgets (critical P95 ≤ 20ms; standard ≤ 50ms; complex ≤ 100ms).
- Phase 3 — Sustainability: Versioning (`.manifest: revision`), input/data schemas, and deprecation workflow with migration notes.

Decision Contract (canonical paths)
- Use `data.charter.article_i.integrity.allow`, `data.charter.article_ii.capital.allow`, and `data.charter.article_iii.entity.allow` to mirror Charter structure for auditability.
