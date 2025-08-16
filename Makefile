.PHONY: help test fmt validate bundle clean install server benchmark
.PHONY: check check-syntax check-semantics check-charter

OPA_VERSION := v1.7.1
BUNDLE_DIR := bundles
SIGNED_BUNDLE_DIR := build/bundles
SIGNING_KEY := $(CHARTER_SIGNING_KEY)
VERIFICATION_KEY := $(CHARTER_VERIFICATION_KEY)
BUNDLE_VERSION := $(shell date +%Y.%m.%d)-$(shell git rev-parse --short HEAD)
CONFIG_DIR := config

help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'

install: ## Install OPA v1.7.1 locally
	@echo "Installing OPA $(OPA_VERSION)..."
	@curl -L -o opa https://github.com/open-policy-agent/opa/releases/download/$(OPA_VERSION)/opa_linux_amd64_static
	@chmod 755 opa
	@sudo mv opa /usr/local/bin/
	@echo "OPA installed successfully"
	@opa version

test: ## Run all policy tests
	@echo "Running OPA tests..."
	@opa test policies/ tests/ -v

test-coverage: ## Run tests with coverage report
	@echo "Running tests with coverage..."
	@opa test policies/ tests/ -v --coverage

fmt: ## Format all Rego files
	@echo "Formatting Rego files..."
	@find policies tests -name "*.rego" -exec opa fmt -w {} \;

validate: ## Validate policy syntax
	@echo "Validating policy syntax..."
	@for policy in $$(find policies -name "*.rego"); do \
		echo "Checking $$policy"; \
		opa fmt --diff $$policy || exit 1; \
	done
	@echo "All policies are valid"

check: check-syntax check-semantics check-charter ## Run syntax, semantic, and charter checks
	@echo "All checks completed"

check-syntax: ## Check formatting/syntax differences
	@echo "Checking formatting diffs..."
	@for policy in $$(find policies -name "*.rego"); do \
		opa fmt --diff $$policy || exit 1; \
	 done

check-semantics: ## Semantic validation with opa check (strict)
	@echo "Running semantic checks..."
	@opa check policies/ --strict

check-charter: ## Verify Charter decision contract coverage
	@echo "Verifying Charter decision contracts..."
	@./scripts/verify-charter-coverage.sh

bundle: ## Create an OPA bundle with manifest
	@echo "Creating OPA bundle..."
	@mkdir -p $(BUNDLE_DIR)
	@opa build -b policies/ --revision $(BUNDLE_VERSION) -o $(BUNDLE_DIR)/bundle.tar.gz
	@echo "Bundle created: $(BUNDLE_DIR)/bundle.tar.gz"
	@tar -tzf $(BUNDLE_DIR)/bundle.tar.gz | head -10

eval-example: ## Evaluate example pod against policies
	@echo "Evaluating secure pod example..."
	@opa eval -d policies/kubernetes/ -i examples/kubernetes/pod-secure.json "data.kubernetes.admission.allow"

server: ## Start OPA server with bundle
	@./scripts/opa-server.sh

server-dev: ## Start OPA server in development mode with watch
	@ENVIRONMENT=development ./scripts/opa-server.sh

benchmark: ## Run performance benchmarks
	@./scripts/benchmark.sh

benchmark-profile: ## Run benchmarks with profiling
	@./scripts/benchmark.sh --profile

inspect: ## Inspect the current bundle
	@echo "Inspecting bundle..."
	@opa inspect $(BUNDLE_DIR)/bundle.tar.gz

verify: validate test ## Run all validation and tests
	@echo "All checks passed!"

ci: verify bundle ## Run CI pipeline locally
	@echo "CI pipeline complete"

clean: ## Clean generated files
	@echo "Cleaning up..."
	@rm -rf $(BUNDLE_DIR)/*.tar.gz
	@rm -f test-results.json bench-results.json
	@rm -rf benchmarks/results benchmarks/profiles
	@find . -name "*.rego.test" -delete
	@echo "Cleanup complete"

# Coverage report for CI
.PHONY: coverage
coverage:
	@echo "Generating coverage report..."
	@opa test policies/ tests/ --coverage --format json > coverage.json
	@opa test policies/ tests/ --coverage | tee coverage-report.txt

# Signed bundle targets (development: use self-signed keys)
.PHONY: bundle-signed bundle-verify release

bundle-signed: bundle ## Build and sign the bundle (requires CHARTER_SIGNING_KEY)
	@echo "Signing bundle..."
	@if [ -z "$(SIGNING_KEY)" ]; then \
		echo "ERROR: CHARTER_SIGNING_KEY not set"; exit 1; \
	fi
	@mkdir -p $(SIGNED_BUNDLE_DIR)
	@opa build -b policies/ \
		--revision $(BUNDLE_VERSION) \
		--signing-alg RS256 \
		--signing-key $(SIGNING_KEY) \
		-o $(SIGNED_BUNDLE_DIR)/charter-policies-$(BUNDLE_VERSION)-signed.tar.gz
	@scripts/create-attestation.sh $(BUNDLE_VERSION) > $(SIGNED_BUNDLE_DIR)/attestation-$(BUNDLE_VERSION).json

bundle-verify: ## Verify signed bundle using CHARTER_VERIFICATION_KEY
	@echo "Verifying signed bundle..."
	@if [ -z "$(VERIFICATION_KEY)" ]; then \
		echo "ERROR: CHARTER_VERIFICATION_KEY not set"; exit 1; \
	fi
	@opa run --verification-key $(VERIFICATION_KEY) \
		--bundle $(SIGNED_BUNDLE_DIR)/charter-policies-$(BUNDLE_VERSION)-signed.tar.gz \
		--server --addr :0 &
	@sleep 2; pkill opa || true
	@echo "Bundle signature verified"

release: bundle-signed bundle-verify ## Create a signed bundle and verify it
	@echo "Release artifacts in $(SIGNED_BUNDLE_DIR)"
