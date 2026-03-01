# AKS FinOps Toolkit: Automated Cost Visibility and Rightsizing

> **"How We Saved $3,000+/month on AKS Without Touching a Single Business Feature"**

A production-grade, open-source FinOps observability stack for Azure Kubernetes Service (AKS).
Surface Kubernetes cost waste directly into developer workflows using Prometheus, Grafana, VPA,
and Slack — without proprietary tooling or vendor lock-in.

[![CI](https://github.com/indila01/aks-finops-toolkit/actions/workflows/ci.yaml/badge.svg)](https://github.com/indila01/aks-finops-toolkit/actions/workflows/ci.yaml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## The Problem

Most teams running Kubernetes on AKS treat it as an **opaque cost line item**. Finance sees a
growing Azure bill. Engineers see CPU/memory graphs. Neither team knows *which workloads* are
wasting money or *by how much*.

Common patterns that silently drain budget:
- Pods requesting 2 CPU but using 50m on average
- Memory limits set 10x higher than actual usage
- Zombie namespaces with leftover staging deployments
- No alert when a new service ships with bloated resource requests

In 2026, with cloud costs under scrutiny at every level, this is no longer acceptable.
→ Full context: [docs/problem-context.md](docs/problem-context.md)

---

## The Solution

This toolkit deploys a **self-contained FinOps observability stack** onto any AKS cluster:

| Component | Role |
|---|---|
| **Prometheus + kube-state-metrics** | Scrape real CPU/memory usage vs. requests/limits |
| **Grafana Dashboards (×4)** | Visualize waste per namespace, workload, and node pool |
| **Vertical Pod Autoscaler (VPA)** | Generate rightsizing recommendations automatically |
| **Alertmanager + Slack** | Push cost anomaly alerts to developer channels |
| **Terraform (AKS)** | Reproducible AKS cluster provisioning |
| **Helm Chart** | One-command stack deployment |

→ Architecture decisions: [docs/solution-design.md](docs/solution-design.md)

---

## MVP Scope

See [docs/mvp.md](docs/mvp.md) for the full MVP definition and milestone checklist.

**Phase 1 (this repo — complete):**
- [x] Terraform: AKS cluster + node pools + namespaces
- [x] Helm umbrella chart: kube-prometheus-stack + VPA
- [x] VPA in recommendation mode (no auto-apply)
- [x] 4 Grafana dashboards (resource waste, namespace heatmap, VPA tracker, node pool)
- [x] 3 Slack alert rules (CPU waste, memory waste, zombie namespace)
- [x] 4 recording rules (efficiency ratios + waste totals used by dashboards)
- [x] CLI waste report script
- [x] CI: Terraform validate + Helm lint + manifest validation

**Phase 2 (roadmap):**
- [ ] OpenCost integration for per-namespace $ cost
- [ ] Goldilocks UI for VPA recommendations
- [ ] Auto-labeling via MutatingWebhookConfiguration
- [ ] Weekly cost digest to Slack

---

## Architecture

```
AKS Cluster
├── monitoring namespace
│   ├── Prometheus          (kube-prometheus-stack)
│   ├── Grafana             (4 dashboards auto-provisioned via ConfigMaps)
│   ├── Alertmanager        (Slack webhook, configured via Helm template)
│   ├── kube-state-metrics  (VPA collector enabled)
│   └── node-exporter
├── vpa-system namespace
│   ├── VPA Recommender     (generates recommendations)
│   └── VPA Admission Controller (webhook only — updateMode: Off)
└── your-app namespaces
    └── VerticalPodAutoscaler objects per Deployment
```

---

## Quick Start

### Prerequisites

| Tool | Version | Check |
|---|---|---|
| Azure CLI | latest | `az version` |
| kubectl | >= 1.28 | `kubectl version --client` |
| helm | >= 3.12 | `helm version` |
| terraform | >= 1.7 | `terraform version` |

### 1. Clone the repo

```bash
git clone https://github.com/indila01/aks-finops-toolkit.git
cd aks-finops-toolkit
```

### 2. Deploy AKS (skip if you have an existing cluster)

```bash
cd terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set your location, names, etc.

terraform init
terraform apply

# Get credentials
az aks get-credentials \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw cluster_name)

cd ../../..
```

### 3. Deploy the FinOps Stack

```bash
# Add Helm repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add fairwinds-stable https://charts.fairwinds.com/stable
helm repo update

# Pull chart dependencies
helm dependency update charts/aks-finops-toolkit

# Install — replace YOUR_SLACK_WEBHOOK with your actual webhook URL
helm upgrade --install aks-finops-toolkit charts/aks-finops-toolkit \
  --namespace monitoring \
  --create-namespace \
  --values charts/aks-finops-toolkit/values.yaml \
  --set alertmanager.slack.webhookUrl="https://hooks.slack.com/services/YOUR/WEBHOOK/URL" \
  --wait
```

The Helm chart deploys everything: Prometheus, Grafana, VPA, all 4 dashboards, all alert rules,
and the Alertmanager Slack config.

### 4. Access Grafana

```bash
kubectl port-forward svc/aks-finops-toolkit-grafana 3000:80 -n monitoring
```

Open [http://localhost:3000](http://localhost:3000) — `admin` / `prom-operator`

The 4 FinOps dashboards will be in the **FinOps** folder in Grafana.

### 5. Deploy the test workload

```bash
# Deploys an intentionally over-provisioned Nginx — validates the full pipeline
kubectl apply -f examples/test-deployment.yaml
```

This will appear in Grafana within 5 minutes, receive a VPA recommendation within 30 minutes,
and fire a Slack alert within ~1 hour.

### 6. Run the CLI waste report

```bash
./scripts/waste-report.sh

# Filter by namespace:
./scripts/waste-report.sh finops-test
```

---

## Dashboards

All dashboards are auto-provisioned at deploy time via Grafana's ConfigMap sidecar.

| Dashboard | UID | What it shows |
|---|---|---|
| **Resource Waste Overview** | `finops-waste-01` | CPU/Memory waste ranked by pod — your top rightsizing candidates |
| **Namespace Efficiency Heatmap** | `finops-ns-heatmap-02` | Efficiency % and absolute waste per namespace |
| **VPA Recommendation Tracker** | `finops-vpa-tracker-03` | VPA target/lower/upper bounds per workload and container |
| **Node Pool Utilization** | `finops-node-pool-04` | Node CPU/memory utilization, bin-packing efficiency, cluster capacity |

---

## Slack Alerts

Configured in `charts/aks-finops-toolkit/templates/prometheus-rules.yaml`.
All alerts include the pod name, namespace, waste ratio, and a link to VPA recommendations.

| Alert | Condition | Window |
|---|---|---|
| `PodCPUOverprovisioned` | CPU request > 3× 7-day average usage | Fires after 1h sustained |
| `PodMemoryOverprovisioned` | Memory request > 3× 7-day average usage | Fires after 1h sustained |
| `ZombieNamespace` | Namespace with pods but < 1m CPU for 7 days | Fires after 7d |
| `ClusterCPUEfficiencyLow` | Cluster-wide CPU efficiency < 20% | Fires after 4h |

---

## VPA Recommendations

VPA runs in **`updateMode: Off`** — recommendations only, no pod evictions.

```bash
# View all recommendations across namespaces
kubectl describe vpa --all-namespaces

# Or check the VPA Recommendation Tracker dashboard in Grafana
```

To apply a recommendation manually, update `resources.requests` in the Deployment and redeploy.

---

## Project Structure

```
aks-finops-toolkit/
├── .github/workflows/
│   └── ci.yaml                    # Terraform validate + Helm lint + kubeconform
├── charts/
│   └── aks-finops-toolkit/
│       ├── Chart.yaml             # Umbrella chart (kube-prometheus-stack + vpa deps)
│       ├── values.yaml            # All configuration with documented defaults
│       └── templates/
│           ├── _helpers.tpl       # Helm label helpers
│           ├── alertmanager-config.yaml  # Slack routing (properly templated)
│           ├── prometheus-rules.yaml     # All alert + recording rules
│           ├── grafana-dashboards.yaml   # All 4 dashboards as ConfigMaps
│           └── NOTES.txt          # Post-install guidance
├── docs/
│   ├── problem-context.md         # Full problem framing with anti-patterns
│   ├── solution-design.md         # Architecture decisions and trade-offs
│   ├── mvp.md                     # MVP definition, milestones, definition of done
│   ├── gaps.md                    # Gap tracking (resolved at MVP)
│   └── medium-article-draft.md    # Medium article draft
├── examples/
│   └── test-deployment.yaml       # Over-provisioned Nginx + VPA object for testing
├── manifests/
│   ├── alerting/                  # Standalone PrometheusRules (for kubectl apply workflows)
│   ├── grafana/                   # Standalone dashboard ConfigMaps
│   └── vpa/                       # VPA object templates for your own workloads
├── scripts/
│   └── waste-report.sh            # CLI waste summary (read-only, no cluster changes)
└── terraform/
    ├── modules/
    │   └── aks/                   # Reusable AKS cluster module
    └── environments/
        └── dev/                   # Dev entry point — variables, outputs, README
```

> **Note on `manifests/`:** These are standalone YAML files for teams that prefer `kubectl apply`
> over Helm. The Helm chart (`charts/`) is the primary deployment method and includes all the
> same resources. You do not need to apply `manifests/` separately when using the Helm chart.

---

## Who Is This For?

- **Platform Engineers** building internal developer platforms on AKS
- **Senior Software Engineers** who own their team's infrastructure costs
- **DevOps/SRE teams** adding FinOps practices to existing clusters
- **Engineering Managers** who need to justify Kubernetes spend to finance

---

## Contributing

PRs welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for design principles and guidelines.

---

## License

MIT — see [LICENSE](LICENSE)
