.PHONY: help test fmt validate bundle clean install server benchmark

OPA_VERSION := v1.7.1
BUNDLE_DIR := bundles
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

bundle: ## Create an OPA bundle with manifest
	@echo "Creating OPA bundle..."
	@mkdir -p $(BUNDLE_DIR)
	@opa build -b policies/ -b data/ -b .manifest -o $(BUNDLE_DIR)/bundle.tar.gz
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