# Policy as Code

Open Policy Agent (OPA) rules and policies for organizational governance.

## Overview

This repository contains OPA policies that enforce security, compliance, and best practices across our infrastructure and applications.

## Repository Structure

```
.
├── policies/          # OPA policy files organized by domain
│   ├── kubernetes/    # Kubernetes admission control policies
│   ├── terraform/     # Terraform plan validation policies
│   ├── docker/        # Docker image and container policies
│   └── github/        # GitHub repository and workflow policies
├── data/              # Static data files used by policies
├── examples/          # Example inputs and test cases
├── tests/             # Policy test files
└── .github/workflows/ # CI/CD workflows for policy validation
```

## Getting Started

### Prerequisites

- [Open Policy Agent](https://www.openpolicyagent.org/docs/latest/#running-opa) (OPA) CLI
- [opa-test](https://www.openpolicyagent.org/docs/latest/policy-testing/) for testing policies
- [Conftest](https://www.conftest.dev/) for validating configurations (optional)

### Installation

1. Install OPA:
```bash
# macOS
brew install opa

# Linux
curl -L -o opa https://openpolicyagent.org/downloads/latest/opa_linux_amd64_static
chmod 755 opa
sudo mv opa /usr/local/bin/
```

2. Clone this repository:
```bash
git clone git@github-personal:verlyn13/policy-as-code.git
cd policy-as-code
```

### Running Policies

#### Evaluate a policy:
```bash
opa eval -d policies/kubernetes/ -i examples/kubernetes/pod.json "data.kubernetes.admission.deny[x]"
```

#### Test policies:
```bash
opa test policies/ tests/ -v
```

#### Use with Conftest:
```bash
conftest verify --policy policies/terraform/ examples/terraform/plan.json
```

## Policy Categories

### Kubernetes Policies
- Pod security standards
- Resource limits and requests
- Network policies
- RBAC validation

### Terraform Policies
- Resource tagging requirements
- Security group rules
- IAM policy restrictions
- Cost optimization rules

### Docker Policies
- Base image restrictions
- Security scanning requirements
- Label requirements
- User permissions

### GitHub Policies
- Branch protection rules
- Secret scanning
- Dependency management
- Workflow security

## Contributing

1. Create a new branch for your policy
2. Add policy files in the appropriate directory
3. Include test cases in `tests/`
4. Update documentation as needed
5. Submit a pull request

## Testing

All policies must include comprehensive tests. Run tests locally before submitting:

```bash
# Run all tests
opa test policies/ tests/ -v

# Run specific domain tests
opa test policies/kubernetes/ tests/kubernetes/ -v
```

## CI/CD

GitHub Actions workflows automatically:
- Validate policy syntax
- Run all policy tests
- Check policy coverage
- Lint Rego files

## License

[Add your license here]

## Resources

- [OPA Documentation](https://www.openpolicyagent.org/docs/latest/)
- [Rego Language Reference](https://www.openpolicyagent.org/docs/latest/policy-language/)
- [OPA Playground](https://play.openpolicyagent.org/)
- [Conftest](https://www.conftest.dev/)
