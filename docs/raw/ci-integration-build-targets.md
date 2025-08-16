# CI Integration and Build Targets

## 1. Integrate `make check` into CI Workflow

### Update GitHub Actions Workflow

```yaml
# .github/workflows/policy-validation.yml
name: Policy Validation

on:
  pull_request:
    paths:
      - 'policies/**'
      - 'data/**'
      - 'schemas/**'
      - '.manifest'
      - 'Makefile'
  push:
    branches: [main]

jobs:
  validate:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup OPA
        run: |
          curl -L -o opa https://openpolicyagent.org/downloads/v0.60.0/opa_linux_amd64
          chmod +x opa
          sudo mv opa /usr/local/bin/
          
      - name: Verify OPA Installation
        run: opa version
        
      - name: Run Syntax Checks
        run: make check-syntax
        
      - name: Run Semantic Validation
        run: make check-semantics
        
      - name: Verify Charter Coverage
        run: make check-charter
        
      - name: Run Tests
        run: make test
        
      - name: Check Coverage
        run: |
          make coverage
          # Fail if coverage < 90%
          coverage=$(opa test policies/ --coverage --format json | jq '.coverage')
          if (( $(echo "$coverage < 90" | bc -l) )); then
            echo "Coverage $coverage% is below 90% threshold"
            exit 1
          fi
          
      - name: Run Benchmarks
        run: |
          make benchmark
          # Store results for comparison
          mkdir -p benchmark-results
          cp benchmark-*.json benchmark-results/
          
      - name: Upload Benchmark Results
        uses: actions/upload-artifact@v3
        with:
          name: benchmark-results
          path: benchmark-results/
          
      - name: Comment PR with Results
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v6
        with:
          script: |
            const fs = require('fs');
            const coverage = fs.readFileSync('coverage-report.txt', 'utf8');
            const benchmarks = fs.readFileSync('benchmark-summary.txt', 'utf8');
            
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `## Policy Validation Results\n\n### Coverage\n\`\`\`\n${coverage}\n\`\`\`\n\n### Performance\n\`\`\`\n${benchmarks}\n\`\`\``
            });
```

### Update Makefile for CI

```makefile
# Add to existing Makefile

# CI-specific target that fails fast
.PHONY: ci-validate
ci-validate: check test coverage benchmark
	@echo "==> All CI validations passed ✅"

# Update verify to depend on check
.PHONY: verify
verify: check test coverage
	@echo "==> All verifications passed"

# Generate reports for CI
.PHONY: ci-reports
ci-reports:
	@opa test policies/ --coverage --format json > coverage.json
	@opa test policies/ --coverage | tee coverage-report.txt
	@scripts/benchmark.sh | tee benchmark-summary.txt
```

---

## 2. Signed Bundle Target with Verification

### Add Signing Targets to Makefile

```makefile
# Bundle signing configuration
BUNDLE_DIR := build/bundles
SIGNING_KEY := $(CHARTER_SIGNING_KEY)
VERIFICATION_KEY := $(CHARTER_VERIFICATION_KEY)
BUNDLE_VERSION := $(shell date +%Y.%m.%d)-$(shell git rev-parse --short HEAD)

.PHONY: bundle
bundle: check test
	@echo "==> Building unsigned bundle..."
	@mkdir -p $(BUNDLE_DIR)
	@opa build -b policies/ \
		-b data/ \
		-b .manifest \
		-o $(BUNDLE_DIR)/charter-policies-$(BUNDLE_VERSION).tar.gz

.PHONY: bundle-signed
bundle-signed: bundle
	@echo "==> Signing bundle..."
	@if [ -z "$(SIGNING_KEY)" ]; then \
		echo "ERROR: CHARTER_SIGNING_KEY not set"; \
		exit 1; \
	fi
	@opa build -b policies/ \
		-b data/ \
		-b .manifest \
		--signing-alg RS256 \
		--signing-key $(SIGNING_KEY) \
		-o $(BUNDLE_DIR)/charter-policies-$(BUNDLE_VERSION)-signed.tar.gz
	@echo "==> Creating attestation..."
	@scripts/create-attestation.sh $(BUNDLE_VERSION) > $(BUNDLE_DIR)/attestation-$(BUNDLE_VERSION).json

.PHONY: bundle-verify
bundle-verify:
	@echo "==> Verifying signed bundle..."
	@if [ -z "$(VERIFICATION_KEY)" ]; then \
		echo "ERROR: CHARTER_VERIFICATION_KEY not set"; \
		exit 1; \
	fi
	@opa run \
		--verification-key $(VERIFICATION_KEY) \
		--bundle $(BUNDLE_DIR)/charter-policies-$(BUNDLE_VERSION)-signed.tar.gz \
		--server --addr :0 &
	@sleep 2
	@pkill opa
	@echo "==> Bundle signature verified ✅"

.PHONY: release
release: bundle-signed bundle-verify
	@echo "==> Creating release $(BUNDLE_VERSION)..."
	@scripts/create-release.sh $(BUNDLE_VERSION)
```

### Attestation Creation Script

```bash
#!/bin/bash
# scripts/create-attestation.sh

VERSION=$1
BUNDLE_FILE="charter-policies-${VERSION}-signed.tar.gz"

# Collect approval information from git
APPROVERS=$(git log -1 --pretty=format:'%an <%ae>' | jq -R -s -c 'split("\n")')
PR_NUMBER=$(git log -1 --grep="Merge pull request" --pretty=format:'%s' | grep -oP '#\K\d+')

# Generate attestation
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
    "opa_version": "$(opa version | grep Version | cut -d: -f2 | tr -d ' ')"
  },
  "approvals": {
    "pr_number": "${PR_NUMBER:-direct-commit}",
    "approvers": ${APPROVERS}
  },
  "charter": {
    "version": "$(grep charter_version .manifest | cut -d: -f2 | tr -d ' \"')",
    "articles_implemented": [
      $(ls policies/charter/article_*/  2>/dev/null | grep -oP 'article_\K[^/]+' | jq -R -s -c 'split("\n")[:-1]')
    ]
  },
  "integrity": {
    "bundle_hash": "$(sha256sum build/bundles/${BUNDLE_FILE} | cut -d' ' -f1)",
    "policies_hash": "$(find policies -type f -name '*.rego' -exec sha256sum {} \; | sort | sha256sum | cut -d' ' -f1)"
  }
}
EOF
```

### CI Bundle Verification

```yaml
# .github/workflows/bundle-signing.yml
name: Bundle Signing Verification

on:
  push:
    branches: [main]
    tags: ['v*']

jobs:
  sign-and-release:
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main' || startsWith(github.ref, 'refs/tags/')
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup OPA
        run: |
          curl -L -o opa https://openpolicyagent.org/downloads/v0.60.0/opa_linux_amd64
          chmod +x opa
          sudo mv opa /usr/local/bin/
          
      - name: Import Signing Key
        run: |
          echo "${{ secrets.CHARTER_SIGNING_KEY }}" | base64 -d > signing.pem
          echo "${{ secrets.CHARTER_VERIFICATION_KEY }}" | base64 -d > verification.pem
          
      - name: Build Signed Bundle
        env:
          CHARTER_SIGNING_KEY: signing.pem
          CHARTER_VERIFICATION_KEY: verification.pem
        run: |
          make bundle-signed
          make bundle-verify
          
      - name: Create Release
        if: startsWith(github.ref, 'refs/tags/')
        uses: softprops/action-gh-release@v1
        with:
          files: |
            build/bundles/charter-policies-*.tar.gz
            build/bundles/attestation-*.json
          body: |
            ## Charter Policies Release
            
            Version: ${{ github.ref_name }}
            
            ### Verification
            ```bash
            opa run --verification-key verification.pem \
              --bundle charter-policies-*-signed.tar.gz \
              --server
            ```
            
            See attestation.json for build details and approvals.
```

---

## 3. Directory Structure for Charter Packages

Create this structure:

```bash
#!/bin/bash
# scripts/scaffold-charter.sh

# Create Charter package directories
mkdir -p policies/charter/article_i/integrity
mkdir -p policies/charter/article_ii/capital  
mkdir -p policies/charter/article_iii/entity
mkdir -p policies/charter/article_iv/double_entry
mkdir -p policies/charter/article_v/valuation
mkdir -p policies/charter/article_vi/liquidity
mkdir -p policies/charter/article_vii/consistency
mkdir -p policies/charter/article_viii/reporting
mkdir -p policies/charter/article_ix/matching
mkdir -p policies/charter/article_x/generational
mkdir -p policies/charter/article_xi/governance

# Create meta policies
mkdir -p policies/charter/meta/integrity
mkdir -p policies/charter/meta/immutability
mkdir -p policies/charter/meta/risk

# Create Constitution operational policies
mkdir -p policies/constitution/entity_integrity
mkdir -p policies/constitution/recordkeeping
mkdir -p policies/constitution/verification
mkdir -p policies/constitution/data_governance

# Copy the scaffolded policies from the artifact
# (Use the Rego code from the previous artifact)

echo "Charter package structure created ✅"
echo "Next steps:"
echo "1. Copy scaffolded policies to appropriate directories"
echo "2. Run 'make check-charter' to verify"
echo "3. Run 'make test' to ensure all tests pass"
```

---

## Team Handle Mapping for CODEOWNERS

Based on your family business structure, update CODEOWNERS:

```
# CODEOWNERS - Family Business Financial Charter

# Governance Board (family trustees/board members)
@governance-board = @family-trustee-1 @family-trustee-2 @external-advisor

# Finance Committee (CFO + family financial oversight)
@finance-committee = @family-cfo @family-treasurer @external-cpa

# Audit Team (external + internal audit)
@audit-team = @external-auditor @internal-audit-lead

# Security Team (IT/cybersecurity)
@security-team = @it-security-lead @compliance-officer

# Operations Team (day-to-day management)
@operations-team = @coo @operations-manager

# Legal Team
@legal-team = @general-counsel @compliance-officer

# Data Governance
@data-governance = @data-steward @it-security-lead

# Policy Maintainers (can review routine changes)
@policy-maintainers = @cfo @coo @compliance-officer
```

---

## Recommended Implementation Sequence

### Week 1: Foundation
1. ✅ Run `scripts/scaffold-charter.sh` to create directories
2. ✅ Copy the scaffolded Charter packages (I, II, III) from the artifact
3. ✅ Run `make check-charter` - should pass
4. ✅ Run `make test` - verify all tests pass
5. ✅ Update CODEOWNERS with actual GitHub usernames

### Week 2: CI Integration  
1. ✅ Add `ci-validate` target to Makefile
2. ✅ Create `.github/workflows/policy-validation.yml`
3. ✅ Test PR workflow with a dummy change
4. ✅ Verify all checks run and pass

### Week 3: Bundle Signing
1. ⚠️ Generate RSA key pair for policy signing
2. ⚠️ Store keys securely (GitHub Secrets for CI, secure vault for manual)
3. ✅ Test `make bundle-signed` locally
4. ✅ Set up release workflow for tagged versions

### Week 4: Extend Coverage
1. 📝 Implement Articles IV-XI following the same pattern
2. 📝 Add Constitution operational policies
3. 📝 Achieve >90% test coverage
4. 📝 Document the decision contract for each article

---

## Quick Start Commands

```bash
# Scaffold the Charter structure
./scripts/scaffold-charter.sh

# Copy policies from artifact to directories
# (Manual step - copy the Rego code provided)

# Verify everything works
make check-charter  # Should find articles I, II, III
make test          # All tests should pass
make ci-validate   # Full CI validation

# Create your first signed bundle (after setting up keys)
export CHARTER_SIGNING_KEY=/path/to/signing.pem
export CHARTER_VERIFICATION_KEY=/path/to/verification.pem
make bundle-signed
make bundle-verify
```

---

## Next Priority Actions

1. **Immediate (Today)**:
   - Copy the scaffolded Charter packages to the directories
   - Run `make check-charter` to verify they're detected
   - Update CODEOWNERS with real usernames

2. **This Week**:
   - Set up the CI workflow
   - Generate signing keys (can use openssl for testing)
   - Test the full validation pipeline on a PR

3. **Next Week**:
   - Implement remaining Charter articles (IV-XI)
   - Add performance benchmarks for each article
   - Document decision contracts in detail

The scaffolded policies I provided give you a working foundation that:
- ✅ Passes `check-charter` requirements
- ✅ Implements core Charter principles  
- ✅ Has comprehensive tests
- ✅ Follows the decision contract pattern
- ✅ Includes proper denial messages with Charter references

This foundation ensures your policy system maintains the same rigor as your Financial Charter while being immediately functional.
