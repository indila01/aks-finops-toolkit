# MVP Definition: AKS FinOps Toolkit

## MVP Goal

Deploy a working FinOps observability stack on AKS that any engineer can clone, configure with their Slack webhook, and have running in under 30 minutes — with actionable cost waste data visible immediately.

**Success criteria:**
- Grafana dashboard shows CPU/memory waste per namespace and workload
- At least one Slack alert fires correctly when a workload is over-provisioned
- VPA recommendations are visible for at least one test workload
- Full deployment is reproducible via Terraform + Helm (no manual Azure portal steps)

---

## In Scope (Phase 1 — this repo)

### Infrastructure
- [x] **Terraform module: AKS cluster** — Single node pool (Standard_D2s_v5), RBAC enabled, managed identity
- [x] **Terraform module: monitoring namespace** — Kubernetes namespace + ClusterRole for Prometheus

### Monitoring Stack
- [x] **kube-prometheus-stack** — Prometheus Operator, Prometheus, Alertmanager, Grafana, kube-state-metrics, node-exporter via Helm umbrella chart
- [x] **VPA deployment** — Admission controller + recommender in `Off` mode

### Dashboards (Grafana, provisioned via Helm templates as ConfigMaps)
- [x] **Resource Waste Overview** — Table ranked by CPU/memory waste per pod (`finops-waste-01`)
- [x] **Namespace Efficiency Heatmap** — Requested vs. actual per namespace, trend over time (`finops-ns-heatmap-02`)
- [x] **VPA Recommendation Tracker** — VPA target/lower/upper bounds per workload (`finops-vpa-tracker-03`)
- [x] **Node Pool Utilization** — Node utilization, bin-packing, cluster capacity gauges (`finops-node-pool-04`)

### Alerting + Recording Rules
- [x] **PodCPUOverprovisioned** — CPU request >3x 7-day average usage, sustained 1h
- [x] **PodMemoryOverprovisioned** — Memory request >3x 7-day average usage, sustained 1h
- [x] **ZombieNamespace** — Namespace with pods but <1m CPU for 7 days
- [x] **ClusterCPUEfficiencyLow** — Cluster-wide efficiency <20%, sustained 4h
- [x] **Recording rules** — `namespace:cpu_efficiency:ratio`, `namespace:memory_efficiency:ratio`,
  `namespace:cpu_waste_millicores:sum`, `namespace:memory_waste_mib:sum`

### Helm Chart
- [x] **Umbrella chart** — wraps `kube-prometheus-stack` + `vpa` as dependencies
- [x] **`_helpers.tpl`** — standard label helpers
- [x] **`alertmanager-config.yaml`** — Slack routing properly templated (webhookUrl injected at install)
- [x] **`prometheus-rules.yaml`** — all alerts and recording rules deployed by Helm
- [x] **`grafana-dashboards.yaml`** — all 4 dashboards deployed by Helm
- [x] **`NOTES.txt`** — post-install guidance printed to terminal
- [x] **`values.yaml`** — sensible defaults, VPA metrics enabled in kube-state-metrics

### Scripts
- [x] **waste-report.sh** — CLI script that prints a formatted waste summary to the terminal using `kubectl` + `jq` (no cluster changes)

---

## Out of Scope (Phase 2 Roadmap)

| Feature | Rationale for deferral |
|---|---|
| **OpenCost integration** | Adds significant complexity; requires Azure billing API credentials |
| **Per-namespace dollar cost attribution** | Depends on OpenCost or Kubecost |
| **VPA Auto mode** | Production risk — needs organizational sign-off |
| **Goldilocks UI** | Nice-to-have wrapper; VPA data already in Grafana |
| **GitHub Actions CI** | Dashboard-as-code validation pipeline |
| **Weekly Slack digest** | Requires CronJob + templating logic |
| **MutatingWebhookConfiguration** | Auto-labeling workloads with cost center tags |
| **Multi-cluster support** | Out of scope; Thanos/Cortex needed for federation |

---

## Non-Functional Requirements

| Requirement | Target |
|---|---|
| Deployment time (fresh AKS) | < 30 minutes |
| Deployment time (existing AKS) | < 10 minutes |
| Prometheus data retention | 15 days (default, configurable) |
| Grafana storage | Ephemeral (dashboards provisioned from ConfigMaps) |
| Alert latency | < 5 minutes from threshold breach to Slack message |
| Terraform plan idempotency | `terraform plan` shows 0 changes after `apply` |

---

## Test Workload

The `examples/` directory includes a `test-deployment.yaml` — an intentionally over-provisioned Nginx deployment:

```yaml
resources:
  requests:
    cpu: "1000m"    # way too high for Nginx serving no traffic
    memory: "512Mi"
  limits:
    cpu: "2000m"
    memory: "1Gi"
```

This will:
1. Appear immediately in the Grafana waste dashboard
2. Trigger a VPA recommendation within ~10 minutes of data collection
3. Fire a Slack alert within ~1 hour of deployment (after the evaluation window)

---

## Milestone Checklist

### M1: Terraform AKS
- [ ] `terraform apply` creates AKS cluster in dev environment
- [ ] `az aks get-credentials` works after apply
- [ ] Node pool visible in Azure portal

### M2: Monitoring Stack Deployed
- [ ] `helm upgrade --install` completes without errors
- [ ] Prometheus targets page shows all expected scrape targets as UP
- [ ] Grafana accessible via port-forward

### M3: Dashboards Working
- [ ] Resource Waste Overview shows data within 5 minutes
- [ ] Namespace Efficiency Heatmap shows at least one namespace
- [ ] VPA dashboard shows pending recommendations after 10+ minutes

### M4: Alerting Working
- [ ] Deploy test workload from `examples/test-deployment.yaml`
- [ ] Confirm PrometheusRule is loaded (`kubectl get prometheusrule -n monitoring`)
- [ ] Wait for evaluation window; confirm Slack alert fires

### M5: Documentation Complete
- [ ] README Quick Start works end-to-end on a fresh AKS cluster
- [ ] All docs in `docs/` reviewed and accurate
- [ ] Medium article draft in `docs/medium-article-draft.md` reflects actual results

---

## Definition of Done

The MVP is complete when:
1. All M1–M5 milestones are checked
2. `waste-report.sh` runs successfully and prints output
3. The GitHub repo is public with README, architecture diagram, and working Helm chart
4. Medium article draft is finished with real screenshots from the deployed stack
