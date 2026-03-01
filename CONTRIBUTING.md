# Contributing to AKS FinOps Toolkit

Thanks for your interest in contributing. This project is designed to be practical, production-safe, and opinionated.

## Design Principles

1. **Read-only by default** — nothing in this toolkit mutates running workloads without explicit opt-in
2. **No proprietary dependencies** — open-source tooling only
3. **Reproducible deployments** — `terraform apply` + `helm install` from scratch, no manual steps
4. **Developer-facing signals** — cost waste should surface where engineers work, not just dashboards

## What We're Looking For

- New Grafana dashboards (as JSON in `manifests/grafana/`)
- Additional PrometheusRules for new waste patterns
- OpenCost integration (Phase 2)
- Improvements to the `waste-report.sh` script
- Tested Terraform configurations for additional environments

## What We're Not Looking For (for now)

- VPA `Auto` mode — too risky for a general-purpose toolkit
- Proprietary vendor integrations
- Additional programming language dependencies (the toolkit uses bash + YAML)

## Local Development Setup

```bash
# Prerequisites
# - kubectl configured against an AKS cluster
# - helm >= 3.12
# - terraform >= 1.7

# Lint Helm chart
helm lint charts/aks-finops-toolkit

# Validate Terraform
cd terraform/modules/aks && terraform init -backend=false && terraform validate

# Test the waste report script (requires a running cluster)
./scripts/waste-report.sh
```

## Submitting Changes

1. Fork the repo and create a branch from `main`
2. Make changes, ensure `helm lint` and `terraform validate` pass
3. Update `docs/` if your change affects architecture or usage
4. Open a PR with a clear description of what changed and why

## Grafana Dashboard Guidelines

- Dashboards must be stored as JSON in `manifests/grafana/` wrapped in a ConfigMap
- The ConfigMap must have label `grafana_dashboard: "1"` to be auto-loaded
- Panel titles should be self-explanatory — no jargon
- All panels should have units set (millicores, MiB, percent, etc.)
- Include thresholds (green/yellow/red) on all gauge and stat panels

## License

By contributing, you agree your contributions will be licensed under the MIT License.
