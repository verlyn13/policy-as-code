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