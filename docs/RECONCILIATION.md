# Reconciliation Workflow

## Overview

Reconciliation is the process of applying validated configurations to actual infrastructure. After policies validate and artifacts are generated, reconcilers ensure the desired state is applied to target systems.

## Architecture

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Decision   │ ──> │  Generated   │ ──> │ Reconcilers  │
│   Contract   │     │  Artifacts   │     │   (Apply)    │
└──────────────┘     └──────────────┘     └──────────────┘
                            │                     │
                            ▼                     ▼
                     .out/journal/*.yaml    Target Systems
                     .out/journal/*.json    - Infisical
                                            - Vercel
                                            - Supabase
```

## Reconciliation Flow

### 1. Validation Phase

```bash
# Ensure everything is valid
make drift-check
make infisical-validate
make platform-validate
make decision
```

### 2. Artifact Generation

```bash
# Generate artifacts from validated configs
make render

# Output structure:
.out/journal/
├── ProjectRole_*.yaml       # Infisical roles
├── identity_*.yaml          # Machine identities
├── binding_*.yaml           # Role bindings
├── vercel-env.json         # Vercel environment
└── supabase-config.json    # Supabase settings
```

### 3. Reconciliation (Apply)

```bash
# Apply to all systems
make reconcile PROJECT=journal

# Or individually:
./scripts/reconcile-infisical.py journal
./scripts/reconcile-vercel.sh journal
./scripts/reconcile-supabase.py journal
```

## Reconcilers

### Infisical Reconciler

**Script**: `scripts/reconcile-infisical.py`

**Purpose**: Applies machine identities, roles, and bindings to Infisical.

**Usage**:
```bash
# Dry run (preview changes)
./scripts/reconcile-infisical.py journal --dry-run

# Apply changes
./scripts/reconcile-infisical.py journal

# With custom config
./scripts/reconcile-infisical.py journal --config ~/.infisical/config.json
```

**Order of Operations**:
1. Create ProjectRoles
2. Create MachineIdentities
3. Create IdentityBindings

**Example Output**:
```
🔄 Reconciling Infisical resources for project: journal

📋 Applying ProjectRoles...
  Applying ProjectRole: runtime (prod)
  Applying ProjectRole: ci (prod)

🤖 Applying MachineIdentities...
  Applying MachineIdentity: token-service@journal-prod (prod)
  Applying MachineIdentity: ci@github-prod (prod)

🔗 Applying IdentityBindings...
  Applying IdentityBinding: token-service-runtime-binding
    Identity: token-service@journal-prod -> Role: runtime

📊 Reconciliation Summary:
  ✅ Applied: 5 resources
```

### Vercel Reconciler

**Script**: `scripts/reconcile-vercel.sh`

**Purpose**: Applies environment variables to Vercel, ensuring no secrets are stored directly.

**Usage**:
```bash
# Dry run
./scripts/reconcile-vercel.sh journal true

# Apply changes
./scripts/reconcile-vercel.sh journal
```

**Security Features**:
- Validates `NEXT_PUBLIC_*` prefix for public vars
- Blocks potential secrets in values
- Ensures server vars are `INFISICAL_*` references
- Fetches actual values from Infisical at runtime

**Example Output**:
```
🔄 Reconciling Vercel environment for project: journal

📋 Applying Public Environment Variables...
  Setting NEXT_PUBLIC_API_URL (production)
  Setting NEXT_PUBLIC_APP_NAME (production)

🔐 Applying Server Environment Variables...
  ✓ INFISICAL_CLIENT_ID is a reference (good)
  ✓ INFISICAL_CLIENT_SECRET is a reference (good)

✅ Vercel environment reconciliation complete!
```

### Supabase Reconciler

**Script**: `scripts/reconcile-supabase.py`

**Purpose**: Configures Supabase authentication, database settings, and RLS.

**Usage**:
```bash
# Dry run
./scripts/reconcile-supabase.py journal --dry-run

# Apply with credentials
./scripts/reconcile-supabase.py journal \
  --supabase-url https://xxx.supabase.co \
  --supabase-key service_role_key
```

**Security Enforcement**:
- JWT expiry must be ≤ 24 hours
- RLS must be enabled on all tables
- Service role key never exposed publicly
- Auth providers configured securely

**Example Output**:
```
🔄 Reconciling Supabase configuration for project: journal

🔐 Applying Authentication Settings...
  ✅ JWT configured: exp=3600s

🗄️ Applying Database Settings...
  ✅ RLS enforced: true

🌍 Applying Environment Variables...
  ✅ Setting NEXT_PUBLIC_SUPABASE_URL
  ✅ Setting NEXT_PUBLIC_SUPABASE_ANON_KEY

✅ Supabase reconciliation complete for project: journal
```

## Makefile Integration

Add to your Makefile:

```makefile
reconcile-infisical: ## Apply Infisical resources
	@./scripts/reconcile-infisical.py $(PROJECT)

reconcile-vercel: ## Apply Vercel environment
	@./scripts/reconcile-vercel.sh $(PROJECT)

reconcile-supabase: ## Apply Supabase configuration
	@./scripts/reconcile-supabase.py $(PROJECT)

reconcile: render reconcile-infisical reconcile-vercel reconcile-supabase ## Full reconciliation
	@echo "✅ All reconcilers completed for $(PROJECT)"

reconcile-dry: ## Dry run reconciliation
	@./scripts/reconcile-infisical.py $(PROJECT) --dry-run
	@./scripts/reconcile-vercel.sh $(PROJECT) true
	@./scripts/reconcile-supabase.py $(PROJECT) --dry-run
```

## CI/CD Integration

### GitHub Actions Job

```yaml
reconcile:
  name: Apply Configuration
  runs-on: ubuntu-latest
  needs: [validation, artifact-generation]
  if: github.ref == 'refs/heads/main'
  
  steps:
  - uses: actions/checkout@v3
  
  - name: Download artifacts
    uses: actions/download-artifact@v3
    with:
      name: decision-artifacts
      path: .out/
  
  - name: Setup tools
    run: |
      pip install pyyaml
      npm install -g vercel
      npm install -g supabase
  
  - name: Reconcile Infisical
    env:
      INFISICAL_TOKEN: ${{ secrets.INFISICAL_TOKEN }}
    run: |
      ./scripts/reconcile-infisical.py ${{ env.PROJECT }}
  
  - name: Reconcile Vercel
    env:
      VERCEL_TOKEN: ${{ secrets.VERCEL_TOKEN }}
    run: |
      ./scripts/reconcile-vercel.sh ${{ env.PROJECT }}
  
  - name: Reconcile Supabase
    env:
      SUPABASE_SERVICE_KEY: ${{ secrets.SUPABASE_SERVICE_KEY }}
    run: |
      ./scripts/reconcile-supabase.py ${{ env.PROJECT }}
```

## Multi-Project Support

### Directory Structure

```
projects/
├── journal/
│   ├── project.yaml
│   └── identities.yaml
├── analytics/
│   ├── project.yaml
│   └── identities.yaml
└── auth-service/
    ├── project.yaml
    └── identities.yaml

data/
├── infisical/
│   ├── journal/
│   ├── analytics/
│   └── auth-service/
└── platforms/
    ├── vercel/
    │   ├── journal.yaml
    │   └── analytics.yaml
    └── supabase/
        ├── journal.yaml
        └── auth-service.yaml
```

### Reconcile Multiple Projects

```bash
#!/bin/bash
# reconcile-all.sh

PROJECTS="journal analytics auth-service"

for project in $PROJECTS; do
  echo "Reconciling $project..."
  
  # Validate
  make drift-check PROJECT=$project
  make infisical-validate PROJECT=$project
  make platform-validate PROJECT=$project
  
  # Generate and apply
  make decision PROJECT=$project
  make render PROJECT=$project
  make reconcile PROJECT=$project
  
  echo "✅ $project reconciled"
done
```

## Error Handling

### Common Issues

#### 1. Authentication Failures

```bash
# Infisical auth issue
export INFISICAL_CLIENT_ID=xxx
export INFISICAL_CLIENT_SECRET=yyy
./scripts/reconcile-infisical.py journal

# Vercel auth issue
vercel login
./scripts/reconcile-vercel.sh journal

# Supabase auth issue
supabase login
./scripts/reconcile-supabase.py journal
```

#### 2. Partial Reconciliation

If reconciliation fails partway:

```bash
# Check current state
make status PROJECT=journal

# Resume from specific reconciler
./scripts/reconcile-vercel.sh journal  # Skip Infisical if already done
./scripts/reconcile-supabase.py journal
```

#### 3. Rollback

To rollback changes:

```bash
# Restore previous artifacts
git checkout HEAD~1 -- .out/journal/

# Re-apply
make reconcile PROJECT=journal
```

## Monitoring & Audit

### Track Reconciliation

```bash
# Log all reconciliations
echo "$(date): Reconciled $PROJECT" >> reconciliation.log

# Audit trail
git add .out/journal/
git commit -m "chore: Reconciled journal $(date +%Y%m%d-%H%M%S)"
```

### Health Checks

```bash
# Verify Infisical
infisical identities list --project journal

# Verify Vercel
vercel env ls

# Verify Supabase
supabase db dump --schema public | grep "ROW LEVEL SECURITY"
```

## Best Practices

1. **Always dry-run first**: Test changes before applying
2. **Version artifacts**: Commit `.out/` after successful reconciliation
3. **Monitor drift**: Run reconciliation regularly to catch drift
4. **Automate in CI**: Apply on merge to main branch
5. **Audit changes**: Keep logs of all reconciliations
6. **Test rollback**: Ensure you can revert changes quickly

## Next Steps

- Implement drift detection between desired and actual state
- Add reconciliation metrics and monitoring
- Create automated rollback on failure
- Implement progressive rollout for multi-region deployments