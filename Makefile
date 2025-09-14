.PHONY: help init validate plan apply destroy clean test-dr remote-plan remote-apply

ENVIRONMENT ?= dev
TERRAFORM_VERSION = 1.13.2
AGENT_HOST = terraform@10.0.1.10
INFISICAL_HOST ?= https://secrets.jefahnierocks.com

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

check-version: ## Verify Terraform version
	@if [ "$$(terraform version -json | jq -r .terraform_version)" != "$(TERRAFORM_VERSION)" ]; then \
		echo "❌ Wrong Terraform version. Expected $(TERRAFORM_VERSION)"; \
		exit 1; \
	fi

init: check-version ## Initialize Terraform
	@echo "🚀 Initializing Terraform for $(ENVIRONMENT)..."
	@cd terraform/environments/$(ENVIRONMENT) && \
		terraform init -upgrade

validate: init ## Validate Terraform configuration
	@echo "✅ Validating configuration..."
	@cd terraform/environments/$(ENVIRONMENT) && \
		terraform validate && \
		terraform fmt -check=true -recursive

plan: validate ## Create execution plan
	@echo "📋 Creating plan for $(ENVIRONMENT)..."
	@cd terraform/environments/$(ENVIRONMENT) && \
		terraform plan \
			-var="infisical_host=$(INFISICAL_HOST)" \
			-out=tfplan-$(ENVIRONMENT)-$$(date +%Y%m%d-%H%M%S)

apply: ## Apply changes (requires confirmation)
	@echo "⚠️  Applying changes to $(ENVIRONMENT)"
	@cd terraform/environments/$(ENVIRONMENT) && \
		terraform apply \
			-var="infisical_host=$(INFISICAL_HOST)" \
			-auto-approve tfplan-$(ENVIRONMENT)-*

remote-plan: ## Execute plan on remote agent
	@./scripts/terraform-remote.sh $(ENVIRONMENT) plan

remote-apply: ## Execute apply on remote agent
	@./scripts/terraform-remote.sh $(ENVIRONMENT) apply

test-dr: ## Test disaster recovery procedure
	@echo "🔥 Testing disaster recovery..."
	@./scripts/test-disaster-recovery.sh

clean: ## Clean up temporary files
	@find . -type f -name "*.tfplan*" -delete
	@find . -type f -name "*.log" -delete
	@find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true

# ============================
# OPA / Policy-as-Code Targets
# ============================

.PHONY: install fmt check-syntax check-semantics test coverage bundle inspect server server-dev benchmark benchmark-profile verify ci

OPA_VERSION ?= v1.7.1
BUNDLE_OUT ?= bundles/bundle.tar.gz

install: ## Install OPA CLI $(OPA_VERSION)
	@which opa >/dev/null 2>&1 || {
		printf "Installing OPA $(OPA_VERSION) ...\n";
		curl -sSL -o /tmp/opa https://github.com/open-policy-agent/opa/releases/download/$(OPA_VERSION)/opa_linux_amd64_static && \
		chmod 755 /tmp/opa && sudo mv /tmp/opa /usr/local/bin/opa; \
	}
	@opa version

fmt: ## Check Rego formatting (diff only)
	@echo "Checking policy formatting..."
	@find policies -type f -name '*.rego' -print0 | xargs -0 -I{} sh -c 'opa fmt --diff "{}"'

check-syntax: ## Validate Rego files parse and format cleanly
	@echo "Validating policy syntax..."
	@opa fmt -l policies | sed 's/^/Needs fmt: /' | tee /dev/stderr; test $$(opa fmt -l policies | wc -l) -eq 0

check-semantics: ## Static analysis: strict checks on policies
	@echo "Running semantic checks..."
	@opa check policies/ --strict

test: ## Run policy tests (verbose)
	@echo "Running OPA tests..."
	@opa test policies/ tests/ -v

coverage: ## Generate coverage.json (threshold enforced in CI)
	@echo "Generating coverage report..."
	@opa test policies/ tests/ --coverage --format json > coverage.json
	@jq -r '.coverage // 0' coverage.json | awk '{printf "Coverage: %s%%\n", $$1}'

bundle: ## Build OPA bundle artifact
	@echo "Building OPA bundle -> $(BUNDLE_OUT)"
	@mkdir -p bundles
	@opa build -b policies/ -b data/ -b .manifest -o $(BUNDLE_OUT)

inspect: bundle ## Inspect compiled bundle
	@opa inspect $(BUNDLE_OUT)

server: bundle ## Start OPA server (production defaults)
	@ENVIRONMENT=production ./scripts/opa-server.sh

server-dev: ## Start OPA server with watch + console logs
	@ENVIRONMENT=development ./scripts/opa-server.sh --build

benchmark: ## Run performance benchmarks and thresholds
	@./scripts/benchmark.sh

benchmark-profile: ## Run benchmarks with CPU profiling
	@./scripts/benchmark.sh --profile

verify: ## Full local verification (fmt, check, tests, coverage, bundle)
	@$(MAKE) fmt
	@$(MAKE) check-semantics
	@$(MAKE) test
	@$(MAKE) coverage
	@$(MAKE) bundle

ci: ## Local CI run (verify + benchmark)
	@$(MAKE) verify
	@$(MAKE) benchmark

infisical-validate: ## Evaluate Infisical intents (journal) and print decision
	@echo "Validating Infisical intents..."
	@opa eval -d policies/infisical/ -d data/ 'data.infisical.intent.decision' -f json | tee infisical-decision.json
	@jq -e '.result[0].expressions[0].value.allowed == true' infisical-decision.json >/dev/null || { echo "Infisical intents failed policy"; exit 1; }

platform-validate-vercel: ## Validate Vercel configs under data/platforms/vercel
	@set -e; for f in $$(find data/platforms/vercel -type f -name '*.yaml' -o -name '*.json'); do \
		echo "Validating Vercel: $$f"; \
		opa eval -d policies/vercel -i $$f 'data.vercel.app.decision' -f json | jq -e '.result[0].expressions[0].value.allowed == true' >/dev/null || { echo "Vercel policy failed for $$f"; exit 1; }; \
	done; echo "✓ Vercel platform configs valid"

platform-validate-supabase: ## Validate Supabase configs under data/platforms/supabase
	@set -e; for f in $$(find data/platforms/supabase -type f -name '*.yaml' -o -name '*.json'); do \
		echo "Validating Supabase: $$f"; \
		opa eval -d policies/supabase -i $$f 'data.supabase.project.decision' -f json | jq -e '.result[0].expressions[0].value.allowed == true' >/dev/null || { echo "Supabase policy failed for $$f"; exit 1; }; \
	done; echo "✓ Supabase platform configs valid"

platform-validate: platform-validate-vercel platform-validate-supabase ## Validate all platform configs

decision: ## Emit project decision JSON for journal to .out/journal/decision.json
	@mkdir -p .out/journal
	@opa eval -d policies/ -d data/ 'data.decision.journal.contract' -f json | jq -r '.result[0].expressions[0].value' > .out/journal/decision.json
	@echo "Wrote .out/journal/decision.json" && jq '.' .out/journal/decision.json | sed -n '1,40p'

drift-check: ## Ensure projects/ and data/ mirrors are in sync for journal
	@opa eval -d policies/ -d data/ -d projects/ 'data.infisical.drift.decision' -f json | jq -e '.result[0].expressions[0].value.allowed == true' >/dev/null || { echo "Drift detected between projects/ and data/"; exit 1; }
