.PHONY: help test fmt validate bundle clean install

help: ## Show this help message
	@echo "Usage: make [target]"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-15s %s\n", $$1, $$2}'

install: ## Install OPA locally
	@echo "Installing OPA..."
	@curl -L -o opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64_static
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

bundle: ## Create an OPA bundle
	@echo "Creating OPA bundle..."
	@opa build -b policies/ -o bundle.tar.gz
	@echo "Bundle created: bundle.tar.gz"

eval-example: ## Evaluate example pod against policies
	@echo "Evaluating secure pod example..."
	@opa eval -d policies/kubernetes/ -i examples/kubernetes/pod-secure.json "data.kubernetes.admission.allow"

clean: ## Clean generated files
	@echo "Cleaning up..."
	@rm -f bundle.tar.gz
	@rm -f test-results.json
	@find . -name "*.rego.test" -delete