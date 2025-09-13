# Policy Codex - Governance-Aligned Technical Standards
*Ensuring Long-Term Trustworthiness of the Financial Charter Policy System*

---

## 1. Decision Contract Specification

### Why This Matters for Your Charter
Your Charter requires an "unbroken audit trail" (Article I). A formal decision contract ensures every policy evaluation produces consistent, auditable outputs regardless of who writes the policy or when.

### Implementation

```yaml
# decision-contract.yaml
---
version: 1.0
domains:
  financial_transactions:
    canonical_path: data.charter.transaction.allow
    input_schema: schemas/transaction-input.json
    output_contract:
      required_fields:
        - allow: boolean
        - decision_id: string
        - severity: enum[INFO, WARN, ALERT, CRITICAL, LOCKDOWN]
        - timestamp: number
        - evaluated_policies: array[string]
      optional_fields:
        - warnings: array[object]
        - denials: array[object]
        - override_available: boolean
    sla:
      p50_ms: 10
      p95_ms: 50
      p99_ms: 100
      
  reconciliation:
    canonical_path: data.charter.reconciliation.status
    input_schema: schemas/reconciliation-input.json
    output_contract:
      required_fields:
        - status: enum[current, due_soon, overdue, critical]
        - days_since: number
        - account_id: string
      optional_fields:
        - next_due_date: string
        - remediation_required: boolean
```

### Validation in CI

```bash
#!/bin/bash
# scripts/validate-decisions.sh

# Validate all decision paths exist
for domain in $(yq eval '.domains | keys | .[]' decision-contract.yaml); do
    path=$(yq eval ".domains.$domain.canonical_path" decision-contract.yaml)
    if ! grep -r "$path" policies/; then
        echo "ERROR: Canonical path $path not found in policies"
        exit 1
    fi
done

# Validate schema compliance
opa eval -d policies/ -i test-inputs/sample-transaction.json \
    'data.charter.transaction' | \
    jq -e '.allow != null and .decision_id != null' || exit 1
```

---

## 2. Validation Checks Beyond Formatting

### Why This Matters for Your Charter
Article IV requires the accounting equation to be "preserved at all times." Semantic validation ensures policies actually enforce this, not just look correct.

### Makefile Additions

```makefile
# Semantic validation for policy quality
.PHONY: validate
validate: fmt check test coverage
	@echo "==> Running comprehensive validation..."

.PHONY: check
check:
	@echo "==> Running semantic checks..."
	@opa check policies/ --strict --warn-undefined
	@# Check for common anti-patterns
	@scripts/check-policy-quality.sh
	@# Verify decision contract compliance
	@scripts/validate-decisions.sh
	@# Ensure no dangerous built-ins
	@! grep -r "http.send\|net.lookup_ip_addr\|opa.runtime" policies/ || \
		(echo "ERROR: Dangerous built-ins detected" && exit 1)

.PHONY: check-charter-compliance
check-charter-compliance:
	@echo "==> Verifying Charter Article compliance..."
	@# Every Charter article must have corresponding tests
	@for article in I II III IV V VI VII VIII IX X XI; do \
		test -f "policies/charter/article_$$article"*.rego || \
			echo "WARNING: Article $$article implementation missing"; \
		test -f "policies/charter/article_$$article"*_test.rego || \
			echo "ERROR: Article $$article tests missing" && exit 1; \
	done
```

### Quality Check Script

```bash
#!/bin/bash
# scripts/check-policy-quality.sh

echo "Checking for policy quality issues..."

# Check for missing default rules
for file in policies/**/*.rego; do
    if grep -q "^deny\[" "$file" && ! grep -q "^default allow" "$file"; then
        echo "WARNING: $file has deny rules but no explicit default allow"
    fi
done

# Check for unbounded loops
if grep -r "input\.\*\[_\].*input\.\*\[_\]" policies/; then
    echo "ERROR: Potential O(n²) operation detected"
    exit 1
fi

# Verify all deny rules have messages
for file in policies/**/*.rego; do
    deny_count=$(grep -c "^deny\[" "$file" || true)
    msg_count=$(grep -c "msg :=" "$file" || true)
    if [ "$deny_count" -gt "$msg_count" ]; then
        echo "ERROR: $file has deny rules without messages"
        exit 1
    fi
done
```

---

## 3. Performance Budgets

### Why This Matters for Your Charter
Your Constitution requires "machine-verified" reconciliations (Article III). Performance budgets ensure the system remains responsive enough for real-time transaction processing.

### Performance Configuration

```yaml
# performance-budgets.yaml
---
budgets:
  transaction_evaluation:
    description: "Core transaction approval flow"
    critical_path: true
    thresholds:
      p50_ms: 10
      p95_ms: 50
      p99_ms: 100
      max_ms: 500
    test_input: "test/fixtures/large-transaction.json"
    
  reconciliation_check:
    description: "Account reconciliation status"
    critical_path: false
    thresholds:
      p50_ms: 5
      p95_ms: 20
      p99_ms: 50
      max_ms: 200
    test_input: "test/fixtures/reconciliation.json"
    
  reserve_calculation:
    description: "Capital preservation checks"
    critical_path: true
    thresholds:
      p50_ms: 15
      p95_ms: 75
      p99_ms: 150
      max_ms: 1000
    test_input: "test/fixtures/investment-transaction.json"
```

### Benchmark Script Enhancement

```bash
#!/bin/bash
# scripts/benchmark.sh

set -e

PROFILE_MODE=${1:-"standard"}
BUDGET_FILE="performance-budgets.yaml"

run_benchmark() {
    local name=$1
    local input=$2
    local path=$3
    local p95_budget=$4
    
    echo "Benchmarking $name..."
    
    # Run benchmark
    result=$(opa bench -d policies/ -i "$input" "$path" -f json)
    
    # Extract P95
    p95=$(echo "$result" | jq '.metrics.timer_rego_query_eval_ns.percentiles["95"]' | \
          awk '{print $1/1000000}')  # Convert to ms
    
    # Check against budget
    if (( $(echo "$p95 > $p95_budget" | bc -l) )); then
        echo "❌ FAIL: $name P95 ${p95}ms exceeds budget ${p95_budget}ms"
        
        if [ "$PROFILE_MODE" = "profile" ]; then
            echo "Generating profile..."
            opa eval -d policies/ -i "$input" "$path" \
                --profile --profile-limit 100 \
                > "profiles/${name}_profile.txt"
        fi
        
        exit 1
    else
        echo "✅ PASS: $name P95 ${p95}ms within budget ${p95_budget}ms"
    fi
}

# Run all benchmarks
for budget in $(yq eval '.budgets | keys | .[]' "$BUDGET_FILE"); do
    input=$(yq eval ".budgets.$budget.test_input" "$BUDGET_FILE")
    p95=$(yq eval ".budgets.$budget.thresholds.p95_ms" "$BUDGET_FILE")
    
    # Determine path based on budget name
    case $budget in
        transaction_evaluation)
            path="data.charter.transaction.allow"
            ;;
        reconciliation_check)
            path="data.charter.reconciliation.status"
            ;;
        reserve_calculation)
            path="data.charter.capital.preservation"
            ;;
    esac
    
    run_benchmark "$budget" "$input" "$path" "$p95"
done

echo "All performance budgets met! ✅"
```

---

## 4. Bundle Security

### Why This Matters for Your Charter
Article XI requires that "any deviation from these principles must be... formally documented." Bundle signing ensures policy changes are authorized and traceable.

### Bundle Signing Configuration

```yaml
# .manifest
---
revision: "2024.8.14-001"
roots:
  - charter
  - constitution
metadata:
  charter_version: "1.0"
  constitution_version: "1.0"
  minimum_opa_version: "0.60.0"
signing:
  algorithm: "RS256"
  key_id: "family-business-policy-key-2024"
  scope: "write"
```

### Signing Workflow

```bash
#!/bin/bash
# scripts/sign-bundle.sh

set -e

BUNDLE_DIR="bundle"
KEY_PATH="${POLICY_SIGNING_KEY:-/secure/keys/policy-signing.pem}"
KEY_ID="family-business-policy-key-2024"

# Verify key authorization
if ! scripts/verify-signer-authorization.sh; then
    echo "ERROR: Current user not authorized to sign policies"
    exit 1
fi

# Create bundle
echo "Creating policy bundle..."
opa build -b policies/ \
    -o "${BUNDLE_DIR}/charter-policies.tar.gz" \
    --signing-alg RS256 \
    --signing-key "${KEY_PATH}" \
    --signing-plugin "family-business-signer"

# Verify signature
echo "Verifying bundle signature..."
opa run --verification-key /secure/keys/policy-verify.pem \
    --bundle "${BUNDLE_DIR}/charter-policies.tar.gz" \
    --server 2>&1 | grep -q "Bundle loaded and verified" || \
    (echo "ERROR: Bundle verification failed" && exit 1)

# Create attestation
cat > "${BUNDLE_DIR}/attestation.json" <<EOF
{
    "bundle": "charter-policies.tar.gz",
    "signed_by": "$(whoami)",
    "signed_at": "$(date -Iseconds)",
    "key_id": "${KEY_ID}",
    "charter_version": "$(yq eval '.metadata.charter_version' .manifest)",
    "git_commit": "$(git rev-parse HEAD)",
    "approvals": $(scripts/get-pr-approvals.sh)
}
EOF

echo "Bundle signed successfully"
```

### CI Verification

```yaml
# .github/workflows/verify-bundle.yml
name: Verify Bundle Signatures
on:
  pull_request:
    paths:
      - 'policies/**'
      - '.manifest'

jobs:
  verify:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup OPA
        run: |
          curl -L -o opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64
          chmod +x opa
          
      - name: Verify bundle can be built
        run: |
          ./opa build -b policies/ -o test-bundle.tar.gz
          
      - name: Check for dangerous built-ins
        run: |
          ! tar -xOf test-bundle.tar.gz | grep -E "http\.send|net\.lookup_ip_addr"
          
      - name: Verify signature requirements
        run: |
          # Check that PR has required approvals
          gh pr view ${{ github.event.pull_request.number }} --json reviews \
            | jq -e '.reviews | map(select(.state == "APPROVED")) | length >= 2'
```

---

## 5. Versioning & Release Process

### Why This Matters for Your Charter
Article X requires evaluation of decisions "in light of their impact... over the next 10, 20, and 50 years." Proper versioning ensures policy evolution is traceable across generations.

### Semantic Versioning for Policies

```yaml
# version-policy.yaml
---
versioning:
  format: "YYYY.MM.DD-NNN"  # Date-based with sequence
  
  change_types:
    major:  # Requires Charter amendment (supermajority)
      - Adding new Charter article implementation
      - Removing Charter article implementation
      - Changing core decision logic
      
    minor:  # Requires Constitution amendment (2/3 approval)
      - Adding new Constitution rules
      - Modifying thresholds
      - Adding new data sources
      
    patch:  # Standard approval process
      - Bug fixes
      - Performance improvements
      - Documentation updates
      
  release_artifacts:
    - charter-policies.tar.gz
    - attestation.json
    - changelog.md
    - decision-contract.yaml
```

### Release Script

```bash
#!/bin/bash
# scripts/release.sh

set -e

VERSION=${1:-$(date +%Y.%m.%d)-001}
RELEASE_DIR="releases/${VERSION}"

echo "Preparing release ${VERSION}..."

# Pre-release checks
make validate
make benchmark
make security-scan

# Update manifest
yq eval ".revision = \"${VERSION}\"" -i .manifest

# Generate changelog
scripts/generate-changelog.sh > CHANGELOG.md

# Build and sign bundle
scripts/sign-bundle.sh

# Create release directory
mkdir -p "${RELEASE_DIR}"
cp bundle/charter-policies.tar.gz "${RELEASE_DIR}/"
cp bundle/attestation.json "${RELEASE_DIR}/"
cp CHANGELOG.md "${RELEASE_DIR}/"
cp decision-contract.yaml "${RELEASE_DIR}/"

# Create GitHub release
gh release create "v${VERSION}" \
    --title "Charter Policies ${VERSION}" \
    --notes-file CHANGELOG.md \
    "${RELEASE_DIR}"/*

# Update production reference
echo "${VERSION}" > production-version.txt

echo "Release ${VERSION} completed"
```

---

## 6. Deprecation Policy

### Why This Matters for Your Charter
Article XI states "any deviation... must be temporary, explicitly justified, and formally documented." This includes deprecating rules.

### Deprecation Workflow

```rego
# Example of deprecation metadata
package charter.deprecated

# METADATA
# title: Legacy Reserve Calculation
# deprecated: 2024-08-14
# sunset: 2024-11-14
# replacement: charter.capital.preservation_v2
# migration_notes: |
#   This rule uses the old reserve calculation method.
#   Migrate to preservation_v2 which includes emergency provisions.
#   See migration guide: docs/migrations/reserve-v2.md
# owners:
#   - finance-team
#   - governance-board

import future.keywords.if

# OLD RULE - DEPRECATED
# Will be removed after sunset date
legacy_reserves_adequate if {
    print("WARNING: Using deprecated reserve calculation")
    # ... old logic ...
}
```

### Deprecation Enforcement

```bash
#!/bin/bash
# scripts/check-deprecations.sh

TODAY=$(date +%Y-%m-%d)

echo "Checking for expired deprecations..."

for file in policies/**/*.rego; do
    if grep -q "# sunset:" "$file"; then
        sunset=$(grep "# sunset:" "$file" | cut -d: -f2 | tr -d ' ')
        
        if [[ "$sunset" < "$TODAY" ]]; then
            echo "ERROR: $file contains expired deprecation (sunset: $sunset)"
            exit 1
        elif [[ "$sunset" < $(date -d "+30 days" +%Y-%m-%d) ]]; then
            echo "WARNING: $file deprecation expires soon (sunset: $sunset)"
        fi
    fi
done
```

---

## 7. Data & Input Schemas

### Why This Matters for Your Charter
Article V requires "assets shall be recorded at the lower of cost or market value." Clear schemas ensure consistent valuation across all policies.

### Schema Definitions

```json
// schemas/transaction-input.json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Transaction Input",
  "type": "object",
  "required": [
    "evaluation_context",
    "transaction",
    "data_sources_used"
  ],
  "properties": {
    "evaluation_context": {
      "type": "object",
      "required": ["timestamp", "request_id", "user"],
      "properties": {
        "timestamp": {
          "type": "number",
          "description": "Unix timestamp in nanoseconds"
        },
        "request_id": {
          "type": "string",
          "format": "uuid"
        },
        "user": {
          "type": "object",
          "required": ["id", "name", "roles"],
          "properties": {
            "id": { "type": "string" },
            "name": { "type": "string" },
            "roles": {
              "type": "array",
              "items": { "type": "string" }
            }
          }
        }
      }
    },
    "transaction": {
      "type": "object",
      "required": ["id", "date", "entity", "amount"],
      "properties": {
        "id": { "type": "string" },
        "date": { 
          "type": "string",
          "format": "date-time"
        },
        "entity": {
          "type": "string",
          "enum": ["personal", "litecky_editing", "happy_patterns"]
        },
        "amount": {
          "type": "number",
          "minimum": 0
        },
        "classification": {
          "type": "string",
          "enum": ["standard", "critical", "high_value", "investment"]
        }
      }
    },
    "emergency_override": {
      "type": "object",
      "properties": {
        "active": { "type": "boolean" },
        "justification": { "type": "string" },
        "approvers": {
          "type": "array",
          "minItems": 2,
          "items": {
            "type": "object",
            "required": ["id", "signature_valid", "timestamp"],
            "properties": {
              "id": { "type": "string" },
              "signature_valid": { "type": "boolean" },
              "timestamp": { "type": "string" }
            }
          }
        }
      }
    }
  }
}
```

### Schema Validation in Tests

```rego
# policies/test_helpers/schema_validation.rego
package test.helpers.schema

import future.keywords.if

valid_transaction_input(input) if {
    # Required fields
    input.evaluation_context.timestamp
    input.evaluation_context.request_id
    input.transaction.id
    input.transaction.amount >= 0
    
    # Valid entity
    input.transaction.entity in {
        "personal", 
        "litecky_editing", 
        "happy_patterns"
    }
    
    # Valid classification if present
    not input.transaction.classification
} else = true if {
    input.transaction.classification in {
        "standard",
        "critical", 
        "high_value",
        "investment"
    }
}
```

---

## 8. PR Template & Code Ownership

### Why This Matters for Your Charter
Article VIII requires "variance analyses comparing performance to budget and prior periods." PR templates ensure every change is properly analyzed.

### Pull Request Template

```markdown
<!-- .github/pull_request_template.md -->
## Policy Change Request

### Change Type
- [ ] Charter Amendment (requires supermajority)
- [ ] Constitution Amendment (requires 2/3 approval)
- [ ] Operational Policy Update
- [ ] Bug Fix
- [ ] Performance Improvement
- [ ] Documentation Only

### Charter Compliance
**Which Charter Articles does this change affect?**
- [ ] Article I - Integrity Above All
- [ ] Article II - Preservation of Capital
- [ ] Article III - The Separate Entity
- [ ] Article IV - The Double-Entry Standard
- [ ] Article V - Prudence in Valuation
- [ ] Article VI - Liquidity Safeguards
- [ ] Article VII - Consistency of Method
- [ ] Article VIII - Periodic and Transparent Reporting
- [ ] Article IX - Matching Cause and Effect
- [ ] Article X - Generational Stewardship
- [ ] Article XI - Governance and Review

### Testing
- [ ] All existing tests pass
- [ ] New tests added for new functionality
- [ ] Test coverage maintained above 90%
- [ ] Integration tests updated if needed

### Validation
- [ ] `make fmt` - Code formatted
- [ ] `make check` - Semantic validation passed
- [ ] `make test` - All tests pass
- [ ] `make coverage` - Coverage acceptable
- [ ] `make benchmark` - Performance budgets met
- [ ] `make security-scan` - No vulnerabilities

### Performance Impact
**Benchmark Results:**
```
# Paste output of make benchmark here
```

**If performance degraded, justify why:**

### Risk Assessment
**What could go wrong with this change?**

**How is the risk mitigated?**

### Documentation
- [ ] Policy documentation updated
- [ ] Decision contract updated if needed
- [ ] Input schemas updated if needed
- [ ] User guide updated if needed

### Approvals Required
Based on change type:
- Charter Amendment: @governance-board (supermajority)
- Constitution Amendment: @finance-committee (2/3)
- Operational: @policy-maintainers (2 approvals)

### Rollback Plan
How would we revert this change if needed?

---
**By submitting this PR, I affirm that:**
- This change aligns with the Family Business Financial Charter
- All impacts have been considered
- The change has been tested thoroughly
- Documentation is complete and accurate
```

### CODEOWNERS File

```
# CODEOWNERS
# This file defines who must review changes to different parts of the policy system

# Charter-level policies require governance board approval
/policies/charter/                @governance-board

# Meta policies (system integrity) require security team + governance
/policies/charter/meta/            @security-team @governance-board

# Financial policies require finance committee
/policies/charter/article_i*/      @finance-committee @audit-team
/policies/charter/article_ii*/     @finance-committee @risk-management
/policies/charter/article_iii*/    @legal-team @finance-committee
/policies/charter/article_iv*/     @accounting-team @audit-team

# Constitution operational policies
/policies/constitution/            @operations-team @finance-committee

# Data definitions require data governance approval
/data/                            @data-governance @finance-committee
/schemas/                         @data-governance @engineering

# Test modifications require quality assurance
/tests/                           @qa-team
/scripts/benchmark.sh             @performance-team @qa-team

# Security-critical files
/.manifest                        @security-team @governance-board
/scripts/sign-bundle.sh          @security-team
/performance-budgets.yaml        @performance-team @operations-team

# Documentation can be updated by any maintainer
/docs/                           @policy-maintainers
*.md                             @policy-maintainers

# Default reviewers for everything else
*                                @policy-maintainers
```

---

## Integration Checklist

To implement these improvements:

### Immediate Actions (Week 1)
- [ ] Add `make check` target with semantic validation
- [ ] Create `decision-contract.yaml` with canonical paths
- [ ] Set up performance budgets and update benchmark script
- [ ] Add PR template and CODEOWNERS file

### Short-term (Weeks 2-3)
- [ ] Implement bundle signing workflow
- [ ] Create input/output schemas for each domain
- [ ] Set up deprecation tracking
- [ ] Add schema validation to tests

### Medium-term (Month 1)
- [ ] Establish release process with proper versioning
- [ ] Document data shape conventions
- [ ] Create migration guides for deprecations
- [ ] Set up automated security scanning

### Ongoing
- [ ] Monthly review of performance budgets
- [ ] Quarterly update of CODEOWNERS based on team changes
- [ ] Annual review of decision contracts
- [ ] Continuous improvement of validation checks

---

## Success Metrics

Track these to ensure the improvements are working:

1. **Policy Quality**
   - Zero semantic validation failures in production
   - 100% of policies have decision contracts
   - All deprecations handled before sunset

2. **Performance**
   - 99% of evaluations within budget
   - P95 latency < 50ms for critical paths
   - Zero performance regressions between releases

3. **Security**
   - 100% of bundles cryptographically signed
   - All dangerous built-ins blocked
   - Complete audit trail for all policy changes

4. **Process**
   - Average PR review time < 24 hours
   - 100% compliance with PR template
   - All changes have appropriate approvals

This comprehensive approach ensures your policy system maintains the same level of rigor as your Financial Charter while remaining maintainable across generations.
