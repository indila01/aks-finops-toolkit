# Solution Design: AKS FinOps Observability Stack

## Design Goals

1. **Zero proprietary dependencies** — runs entirely on open-source tooling
2. **Non-invasive** — read-only observation; no auto-mutation of production workloads
3. **Developer-facing** — cost signals surface in Slack, not just dashboards
4. **Reproducible** — full Terraform + Helm deployment from scratch in under 10 minutes
5. **Publish-ready** — clean separation of concerns, documented trade-offs

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         AKS Cluster                             │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                   monitoring namespace                   │   │
│  │                                                          │   │
│  │  ┌─────────────┐    scrape    ┌──────────────────────┐  │   │
│  │  │  Prometheus  │◄────────────│  kube-state-metrics   │  │   │
│  │  │             │◄────────────│  kubelet /metrics     │  │   │
│  │  └──────┬──────┘             └──────────────────────┘  │   │
│  │         │                                               │   │
│  │         │ query             ┌──────────────────────┐   │   │
│  │         └──────────────────►│       Grafana        │   │   │
│  │         │                   │  (dashboards loaded  │   │   │
│  │         │                   │   via ConfigMaps)    │   │   │
│  │         │                   └──────────────────────┘   │   │
│  │         │                                               │   │
│  │         │ alert             ┌──────────────────────┐   │   │
│  │         └──────────────────►│   Alertmanager       │──────────► Slack
│  │                             │  (PrometheusRules)   │   │   │
│  │                             └──────────────────────┘   │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                   vpa-system namespace                   │   │
│  │   VPA Admission Controller (recommendation mode only)    │   │
│  │   VerticalPodAutoscaler objects → updateMode: "Off"      │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                   app namespaces                         │   │
│  │   Deployments with resource requests/limits              │   │
│  │   VPA objects watching each Deployment                   │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## Component Decisions

### Prometheus (via kube-prometheus-stack)

**Why kube-prometheus-stack?**
- Bundles Prometheus Operator, Alertmanager, Grafana, kube-state-metrics, and node-exporter in one Helm chart
- Industry standard — reduces maintenance burden vs. assembling individual components
- ServiceMonitor / PrometheusRule CRDs are the de-facto standard for scrape config

**Key metrics used:**
```promql
# CPU waste signal: requested - actual
container_request_cpu_cores - rate(container_cpu_usage_seconds_total[5m])

# Memory waste signal: requested - actual peak
container_spec_memory_limit_bytes - container_memory_working_set_bytes

# Namespace resource efficiency ratio
sum(rate(container_cpu_usage_seconds_total[1h])) by (namespace)
  /
sum(kube_pod_container_resource_requests{resource="cpu"}) by (namespace)
```

### Grafana Dashboards (as Code)

Dashboards are stored as JSON in `manifests/grafana/` and loaded via Grafana's dashboard provisioning (ConfigMaps). This means:
- Dashboards are version-controlled
- Deployments are idempotent
- No manual import/export steps

**Trade-off:** Dashboard JSON is verbose. We use a `dashboards/` directory per logical domain (cost, vpa, nodes) rather than one giant file.

### Vertical Pod Autoscaler (VPA)

**Mode: `updateMode: "Off"` (recommendation only)**

This is a deliberate safety choice for MVP:
- VPA in `Auto` mode can evict pods during business hours to resize them
- `Off` mode generates `status.recommendation` without touching running pods
- Operators can review recommendations in Grafana and apply manually

To view recommendations:
```bash
kubectl describe vpa <name> -n <namespace>
# or use the Grafana "VPA Recommendation Tracker" dashboard
```

**Why not Goldilocks?**
Goldilocks (Fairwinds) is an excellent wrapper around VPA recommendations. It is NOT included in MVP to keep the dependency surface minimal. It is a natural Phase 2 addition.

### Alertmanager + Slack

PrometheusRules define the alerting logic. Alertmanager routes to Slack.

**Alert logic rationale:**
We use a 7-day lookback window (`[7d]`) rather than a short window to avoid false positives from legitimate traffic spikes. A workload needs to be consistently over-provisioned to trigger an alert.

```yaml
# Example rule
- alert: PodCPUOverprovisioned
  expr: |
    (
      kube_pod_container_resource_requests{resource="cpu"}
      /
      avg_over_time(
        rate(container_cpu_usage_seconds_total[5m])[7d:1h]
      )
    ) > 3
  for: 1h
  labels:
    severity: warning
  annotations:
    summary: "{{ $labels.pod }} CPU request is {{ $value | humanize }}x its actual usage"
```

### Terraform

One reusable module:
- `modules/aks` — AKS cluster, node pools, managed identity, Log Analytics workspace

The monitoring and vpa-system Kubernetes namespaces are created inline in `environments/dev/main.tf`
using the `kubernetes` provider, keeping the namespace lifecycle bound to the environment rather
than the cluster module. This is simpler for MVP and avoids circular dependency between the cluster
module and a namespace module that would need the cluster outputs.

**Why not a separate monitoring module?**
A dedicated `modules/monitoring` module adds complexity without benefit at MVP scale. One or two
namespace resources don't justify a module boundary. This can be extracted in Phase 2 if multiple
environments need different monitoring configurations.

---

## Data Flow

```
kubelet + cAdvisor
    │
    ▼ (HTTP /metrics)
Prometheus scrapes every 30s
    │
    ├─► Alertmanager evaluates PrometheusRules every 1m
    │       │
    │       └─► Slack webhook → #cost-alerts channel
    │
    └─► Grafana queries on dashboard load / refresh
            │
            └─► Engineers see waste ranked by namespace/workload
```

---

## Security Considerations

- Prometheus scrapes only within-cluster targets (no external exposure)
- Grafana is not exposed via Ingress in MVP — accessed via `kubectl port-forward`
- Slack webhook URL is injected at Helm install time via `--set`, not stored in values files
- VPA admission controller is read-only in `Off` mode — no mutation webhook active
- Terraform state: use Azure Blob Storage backend with state locking (documented in `terraform/environments/dev/README.md`)

---

## What We Are NOT Building (and Why)

| Skipped | Reason |
|---|---|
| OpenCost | Adds complexity; Phase 2 addition for $ cost attribution |
| Kubecost | Proprietary SaaS tier required for full feature set |
| KEDA | Separate concern (scaling, not cost visibility) |
| Grafana Loki | Log aggregation out of scope for FinOps MVP |
| Ingress for Grafana | Security risk for MVP; port-forward is sufficient |
| VPA Auto mode | Production safety — recommendation mode is safer for first deployment |
