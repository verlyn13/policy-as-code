# Repository Structure (Policies + Projects + Platforms)

This repo organizes Policy-as-Code, project intents, and platform configs so multiple projects (with differing settings) can be managed consistently under shared guardrails.

## Layout

- `policies/` — OPA policies by domain
  - `kubernetes/`, `terraform/`, `docker/`, `github/`, `system/`
  - `infisical/` — validates project/identity intents (YAML under `data/infisical/**`)
  - `vercel/` — validates Vercel project configuration inputs
  - `supabase/` — validates Supabase project configuration inputs
  - `lib/` — shared helpers
- `tests/` — Rego policy tests
- `data/` — Static YAML/JSON used as inputs for policies
  - `infisical/<project>/{project.yaml,identities.yaml}` — project + identity intents
  - `platforms/`
    - `vercel/<project>.yaml` — per-project Vercel config inputs
    - `supabase/<project>.yaml` — per-project Supabase config inputs
- `projects/` — Human-authored, canonical project declarations (source of truth)
  - `<project>/project.yaml`
  - `<project>/identities.yaml`
  - (optional) `<project>/platforms/{vercel.yaml,supabase.yaml}`
- `terraform/` — Modules + per-environment configs
- `scripts/` — Ops helpers, validation, signing, and gen tools
- `docs/` — Ops, Audit, and platform docs

## Authoring Flow

1. Author project intents under `projects/<project>/`.
2. Mirror to `data/infisical/<project>/` for OPA evaluation (OPA consumes data here). Automation can sync these.
3. For platforms, add config inputs to `data/platforms/<type>/<project>.yaml`.
4. Run validations:
   - Infisical intents: `make infisical-validate`
   - Platforms: `make platform-validate`

## Adding a New Project

- Create `projects/<slug>/{project.yaml,identities.yaml}` (copy an existing project).
- Create `data/infisical/<slug>/*` (initially copy from `projects/`); wire automation later.
- Optionally add platform inputs under `data/platforms/vercel/<slug>.yaml` and `data/platforms/supabase/<slug>.yaml`.
- Open a PR. CI runs OPA tests and platform/intents validation.

## Why Two Folders (projects vs data)?

- `projects/` holds source-of-truth authored by humans.
- `data/` holds the evaluated view consumed by OPA; it can be generated from `projects/` by a lightweight sync/generator.

