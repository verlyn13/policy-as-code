# Policy as Code Complete Workflow

## Overview

This document describes the complete workflow for managing infrastructure policies, platform configurations, and secret management through Policy as Code.

## Architecture

```
┌─────────────────┐      ┌──────────────┐      ┌─────────────────┐
│   Source of     │      │   OPA Data   │      │   Generated     │
│     Truth       │ ───> │   Mirrors    │ ───> │   Artifacts     │
│  (projects/)    │      │   (data/)    │      │    (.out/)      │
└─────────────────┘      └──────────────┘      └─────────────────┘
         │                       │                       │
         │                       ▼                       │
         │              ┌──────────────┐                │
         └─────────────>│  OPA Policy  │<───────────────┘
                        │  Validation  │
                        └──────────────┘
                                │
                        ┌───────▼────────┐
                        │   Decision     │
                        │   Contract     │
                        └────────────────┘
```

## Directory Structure

```
projects/                   # Source of truth (human-authored)
├── journal/               # Example project
│   ├── project.yaml      # Project configuration
│   └── identities.yaml   # Machine identities & bindings

data/                      # OPA-readable mirrors
├── infisical/            # Secret management configs
│   └── journal/          # Mirrored from projects/journal/
├── platforms/            # Platform-specific configs
│   ├── vercel/          # Vercel environment variables
│   └── supabase/        # Supabase settings

policies/                  # OPA validation rules
├── infisical/           # Intent validation
├── vercel/              # Vercel app policies
├── supabase/            # Supabase project policies
└── decision/            # Contract generation

.out/                     # Generated artifacts (gitignored)
└── journal/             # Output for journal project
    ├── decision.json    # Decision contract
    ├── *.yaml          # Infisical resources
    └── *.json          # Platform configs
```

## Workflow Steps

### 1. Define Project Configuration

Create source of truth in `projects/<project-name>/`:

```yaml
# projects/journal/project.yaml
project_slug: journal
project_id: 507f1f77bcf86cd799439011
description: "Production journal application"
environments:
  - slug: dev
    name: Development
  - slug: stg
    name: Staging
  - slug: prod
    name: Production
```

```yaml
# projects/journal/identities.yaml
project_slug: journal
identities:
  - name: token-service@journal-prod
    type: runtime
    project_role: runtime
    environment: prod
    auth_method:
      type: universal
      access_token_ttl: 3600
    bindings:
      - role: runtime
        paths: ["/auth/jwt/*", "/auth/aes/*"]
```

### 2. Mirror to Data Directory

Sync source to OPA-readable location:

```bash
# Manual sync (for now)
cp -r projects/journal/* data/infisical/journal/

# Or use make target (when implemented)
make sync-data
```

### 3. Add Platform Configurations

Define platform-specific settings:

```yaml
# data/platforms/vercel/journal.yaml
public_env:
  NEXT_PUBLIC_API_URL: https://api.journal.com
  NEXT_PUBLIC_APP_NAME: Journal

server_env:
  INFISICAL_CLIENT_ID: "${INFISICAL_CLIENT_ID}"
  INFISICAL_CLIENT_SECRET: "${INFISICAL_CLIENT_SECRET}"
```

```yaml
# data/platforms/supabase/journal.yaml
jwt_secret: "${JWT_SECRET}"
jwt_exp: 3600  # 1 hour
rls_enforced: true
public_env:
  NEXT_PUBLIC_SUPABASE_URL: https://journal.supabase.co
  NEXT_PUBLIC_SUPABASE_ANON_KEY: "${ANON_KEY}"
```

### 4. Run Validations

Execute policy checks:

```bash
# Check for drift between source and data
make drift-check

# Validate Infisical intents
make infisical-validate

# Validate platform configs
make platform-validate

# Or validate everything
make verify
```

### 5. Generate Decision Contract

Create decision JSON with all validations:

```bash
make decision

# Output: .out/journal/decision.json
{
  "project_slug": "journal",
  "project_id": "507f1f77bcf86cd799439011",
  "allowed": true,
  "timestamp": 1757809182392476019,
  "denies": [],
  "warnings": [
    "Bootstrap IP allowlist is broad for prod runtime"
  ],
  "artifacts": [
    ".out/journal/ProjectRole_runtime_prod.yaml",
    ".out/journal/identity_token-service_prod.yaml",
    ".out/journal/vercel-env.json",
    ".out/journal/supabase-config.json"
  ]
}
```

### 6. Generate Artifacts

Create deployment artifacts:

```bash
./scripts/generate-artifacts.sh journal

# Generates:
# - Infisical YAML resources
# - Vercel environment config
# - Supabase configuration
# - Manifest file
```

## CI/CD Integration

### GitHub Actions Workflow

The `.github/workflows/platform-validation.yml` workflow automatically:

1. **Drift Check**: Ensures `projects/` and `data/` are synchronized
2. **Intent Validation**: Validates Infisical configurations
3. **Platform Validation**: Checks Vercel and Supabase configs
4. **Decision Generation**: Creates decision contract
5. **Artifact Generation**: Produces deployment files

### Triggering CI

CI runs automatically on:
- Push to `main` or `develop` branches
- Pull requests to `main`
- Changes to `projects/`, `data/`, `policies/`, or `schemas/`

### CI Output

CI produces:
- Validation results in GitHub summary
- Decision contract as artifact
- Generated YAML/JSON files for deployment

## Validation Rules

### Infisical Intent Validation

- **Paths**: Only canonical paths allowed (`/auth/jwt/*`, `/auth/aes/*`)
- **Roles**: Must be `runtime`, `ci`, or `security-ops-prj`
- **TTLs**: Enforced limits per identity type
- **Production**: Special rules for prod environment

### Vercel Validation

- Public environment variables must start with `NEXT_PUBLIC_`
- No sensitive values in public config
- Server-side uses `INFISICAL_*` for secrets

### Supabase Validation

- Service role key never exposed publicly
- JWT secret required and TTL ≤ 24 hours
- Row Level Security must be enabled

## Adding a New Project

1. **Create project structure**:
   ```bash
   mkdir -p projects/myapp
   ```

2. **Define configuration**:
   - `projects/myapp/project.yaml`
   - `projects/myapp/identities.yaml`

3. **Mirror to data**:
   ```bash
   cp -r projects/myapp data/infisical/myapp
   ```

4. **Add platform configs**:
   - `data/platforms/vercel/myapp.yaml`
   - `data/platforms/supabase/myapp.yaml`

5. **Validate**:
   ```bash
   make infisical-validate
   make platform-validate
   ```

6. **Generate artifacts**:
   ```bash
   ./scripts/generate-artifacts.sh myapp
   ```

## Troubleshooting

### Drift Detection Failed

```bash
# Check differences
diff -r projects/journal data/infisical/journal

# Sync manually
cp -r projects/journal/* data/infisical/journal/
```

### Validation Failed

```bash
# Check specific validation
opa eval -d policies/infisical -d data/infisical/journal \
  'data.infisical.intent.decision' -f pretty

# Review denials
jq '.denies' .out/journal/decision.json
```

### Schema Validation Failed

```bash
# Validate schemas manually
python scripts/validate-schemas.py

# Check specific file
jsonschema -i projects/journal/project.yaml \
  schemas/project.schema.json
```

## Best Practices

1. **Always start with `projects/`**: This is the source of truth
2. **Run drift-check frequently**: Ensures data stays synchronized
3. **Review warnings**: Non-blocking but important for production
4. **Test locally first**: Use `make` targets before pushing
5. **Monitor CI output**: Check GitHub summary for details
6. **Version control artifacts**: Decision contracts provide audit trail

## Next Steps

### Automation Opportunities

1. **Auto-sync**: Script to automatically mirror projects/ to data/
2. **Reconcilers**: Apply generated artifacts to actual systems
3. **Monitoring**: Track policy decision metrics
4. **Webhooks**: Trigger validation on external events

### Policy Extensions

1. **AWS/GCP**: Add cloud provider policies
2. **Docker**: Container registry policies
3. **Network**: Firewall and CDN rules
4. **Compliance**: SOC2, HIPAA, GDPR checks

## Support

- Repository: https://github.com/verlyn13/policy-as-code
- Issues: https://github.com/verlyn13/policy-as-code/issues
- Documentation: `/docs` directory