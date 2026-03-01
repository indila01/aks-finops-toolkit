# MEDIUM ARTICLE DRAFT
# "How We Saved $3,000+/Month on AKS Without Touching a Single Business Feature"

> **Draft notes:** Replace all `[SCREENSHOT]` markers with actual Grafana screenshots after deploying.
> Replace `$X` values with real numbers from your cluster after running for 1 week.

---

**Tags:** kubernetes, azure, finops, devops, platform-engineering

**Subtitle:** A practical guide to building a cost observability stack with Prometheus, Grafana, VPA, and Slack — open source, no vendor lock-in.

---

## The Day Finance Asked a Question I Couldn't Answer

Our Azure bill had crossed $15,000/month. The CTO forwarded me an email from finance with a single line:

> *"What exactly are we paying for in AKS?"*

I opened the Azure portal. Cost Management showed me one line: `aks-prod — $12,400/month`. That was it. No breakdown by team. No breakdown by service. No indication of what was wasted.

I'd been running Kubernetes for three years. I had Prometheus. I had Grafana. I had 14 dashboards showing CPU and memory graphs. But I couldn't answer the question.

That's when I built the AKS FinOps Toolkit.

---

## The Problem: Three Teams, Three Blind Spots

Here's what I discovered when I started digging:

**Finance** saw: one line item, growing month over month.

**Engineering** saw: CPU and memory graphs with no dollar translation.

**Platform team** (me) saw: node pool sizes and scaling events, but no per-workload waste data.

Nobody was lying. Nobody was ignoring the problem. We just had no shared visibility.

---

## What I Found When I Actually Looked

Once I wired up proper resource waste metrics, three patterns emerged immediately:

### Pattern 1: "Set It and Forget It" Requests

A payment service was running with `requests.cpu: 2000m`. It had been that way since launch, when we load-tested it under 10x production traffic. Actual usage: **~120m CPU** on average.

That's 1880m of reserved CPU sitting idle — on every pod, in every replica.

### Pattern 2: The "I Saw a Spike Once" Memory Limits

Our API gateway had `limits.memory: 4Gi`. It had seen one traffic spike 8 months ago that hit 2.1Gi. The spike passed, the limit stayed.

Current working set: **~380Mi**. The node reserved 4Gi. That capacity was unavailable to any other pod.

### Pattern 3: Ghost Namespaces

A quick `kubectl get ns` showed 23 namespaces. Our production applications lived in 6.

The other 17? Old feature branches, a "performance-testing" namespace from Q3, a "demo-2024-09" namespace that apparently nobody deleted after a sales demo.

Combined, they consumed **~8% of our cluster capacity** doing nothing.

---

## The Solution: Surfacing Waste Where Engineers Actually Look

The fix wasn't complicated. It was about wiring the right metrics to the right places.

**Stack:**
- Prometheus (kube-prometheus-stack) for metrics collection
- Grafana dashboards for waste visualization
- VPA for automated rightsizing recommendations
- Alertmanager + Slack for proactive developer notification

[SCREENSHOT: Grafana Resource Waste Overview dashboard showing pods ranked by CPU waste ratio]

---

## Building It: Step by Step

### Step 1: The Key Metrics

The waste signal is simple:

```promql
# CPU waste: what we reserved vs. what we used
kube_pod_container_resource_requests{resource="cpu"}
-
rate(container_cpu_usage_seconds_total[7d])
```

```promql
# Efficiency ratio per namespace (lower = more waste)
sum(rate(container_cpu_usage_seconds_total[1h])) by (namespace)
/
sum(kube_pod_container_resource_requests{resource="cpu"}) by (namespace)
```

Run those queries in your Prometheus instance right now. The results will surprise you.

### Step 2: A Dashboard That Shows Waste, Not Utilization

Most Kubernetes dashboards show utilization. FinOps needs waste.

Utilization tells you: "this pod is using 15% of its request."
Waste tells you: "this pod has 850m CPU sitting idle, reserved but unused."

[SCREENSHOT: Table panel showing pods ranked by wasted CPU millicores]

The key change is in the panel: instead of a percentage, show absolute millicores (or Mi of memory) that are requested but unused. This is the number finance can relate to.

### Step 3: VPA Recommendations as Data, Not Actions

Vertical Pod Autoscaler (VPA) analyses your historical usage and recommends right-sized requests. Critically, we run it in **recommendation mode only** — it never touches a running pod.

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: my-api-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-api
  updatePolicy:
    updateMode: "Off"   # recommendations only, no auto-apply
```

After 24-48 hours of data collection:

```bash
kubectl describe vpa my-api-vpa

# Status:
#   Recommendation:
#     Container Recommendations:
#       Container Name: my-api
#       Lower Bound:    cpu: 50m, memory: 128Mi
#       Target:         cpu: 120m, memory: 256Mi
#       Upper Bound:    cpu: 300m, memory: 512Mi
```

We built a Grafana dashboard that surfaces all VPA recommendations across every namespace in one view.

[SCREENSHOT: VPA Recommendation Tracker dashboard]

### Step 4: Slack Alerts Before It Becomes a Problem

Dashboards are reactive. Slack alerts are proactive.

The rule that had the most impact:

```yaml
- alert: PodCPUOverprovisioned
  expr: |
    (
      kube_pod_container_resource_requests{resource="cpu"}
      /
      avg_over_time(rate(container_cpu_usage_seconds_total[5m])[7d:1h])
    ) > 3
  for: 1h
  annotations:
    summary: "{{ $labels.pod }} CPU request is {{ $value | humanize }}x its actual usage"
    description: "Consider rightsizing. VPA recommendation available."
```

Now when a new service ships with oversized requests, the team that owns it gets a Slack message within an hour. Cost waste doesn't accumulate for months before anyone notices.

[SCREENSHOT: Slack alert showing pod name, namespace, and waste ratio]

---

## The Results

After deploying this stack and acting on the top 10 recommendations over two weeks:

| Change | Monthly Saving |
|---|---|
| Reduced CPU requests on 6 services | ~$800 |
| Reduced memory limits on 4 services | ~$600 |
| Deleted 8 zombie namespaces | ~$1,100 |
| Right-sized 3 node pools (fewer nodes needed) | ~$900 |
| **Total** | **~$3,400/month** |

The work took about 3 days of engineering time across two people. No new features were touched. No customers were impacted.

---

## Get the Toolkit

Everything described here is open source and ready to deploy:

**GitHub:** `github.com/[your-username]/aks-finops-toolkit`

```bash
git clone https://github.com/[your-username]/aks-finops-toolkit
cd aks-finops-toolkit

# Deploy to existing AKS cluster
helm upgrade --install aks-finops-toolkit ./charts/aks-finops-toolkit \
  --namespace monitoring \
  --create-namespace \
  --set alertmanager.slack.webhookUrl="YOUR_WEBHOOK_URL"
```

Includes:
- Terraform for AKS provisioning
- Helm umbrella chart (Prometheus + Grafana + VPA)
- 4 pre-built Grafana dashboards
- 3 Slack alert rules
- CLI waste report script
- Full documentation

---

## Key Takeaways

1. **Kubernetes utilization dashboards are not FinOps dashboards.** Showing 15% utilization hides the fact that 85% is reserved and billed.

2. **VPA in recommendation mode is safe for any cluster.** You get the data without the risk. Act on it manually.

3. **Surface cost signals in Slack.** Engineers respond to alerts, not dashboards they have to remember to check.

4. **Zombie namespaces are free money.** A `kubectl get ns` audit is the fastest ROI you can get.

5. **You don't need Kubecost or a FinOps vendor for this.** Prometheus + Grafana + VPA is sufficient to capture 80% of the value.

---

*If this was useful, star the repo and share it with your platform engineering team. I'm building Phase 2 with OpenCost integration for dollar-accurate cost attribution — follow along on GitHub.*

---

**Related:**
- [GitHub: aks-finops-toolkit](https://github.com/[your-username]/aks-finops-toolkit)
- [VPA documentation](https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler)
- [FinOps Foundation: Kubernetes Cost Allocation](https://www.finops.org/wg/calculating-container-costs/)
- [Fairwinds State of Kubernetes Security 2024](https://www.fairwinds.com/kubernetes-config-benchmark-report)
