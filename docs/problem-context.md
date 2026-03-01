# Problem Context: Why Kubernetes Cost Visibility Is Broken

## Background

Kubernetes was designed for reliability and scalability — not cost efficiency. The scheduling model encourages engineers to set *high* resource requests to avoid OOMKills and throttling. This is the right engineering instinct. But at scale, it produces a silent tax: you pay for headroom that is never used.

On Azure Kubernetes Service (AKS), this problem compounds:
- Node pools are billed by VM SKU, regardless of actual pod utilization
- Azure Cost Management surfaces AKS as a single line item
- There is no native view of "which pod is wasting the most money"

---

## The Core Disconnect

Three groups interact with Kubernetes cost, and they all see a different picture:

| Stakeholder | What they see | What they're missing |
|---|---|---|
| **Finance** | Azure invoice: AKS = $X/month | Which workloads, teams, or features drive that cost |
| **Engineers** | CPU/memory graphs in Grafana | Translation from utilization % to dollars |
| **Platform Teams** | Node pool sizes, scaling events | Per-workload waste visibility |

This disconnect means no one is accountable for resource bloat. Engineers ship services with `requests.cpu: 500m` because that's what the template says. Finance escalates the bill. Platform teams scale up nodes. Nothing changes.

---

## Observed Patterns (Real-World Anti-Patterns)

### 1. Static Resource Requests Set Once, Never Revisited
A service is launched with `requests.cpu: 1` at go-live under load-test pressure. Six months later it serves 10 req/s and uses 80m CPU. The request is never updated.

### 2. "Safe" Limits That Are 10x Reality
Teams set `limits.memory: 2Gi` because they saw a spike once. The pod runs at 180Mi consistently. The node reserves 2Gi. That capacity is unavailable to other pods.

### 3. Zombie Namespaces
Staging environments, feature-branch deployments, and demo namespaces accumulate. A `kubectl get ns` reveals namespaces not touched in months, still consuming quota.

### 4. No Signal to Developers
Without a Slack alert or dashboard in the developer workflow, there is zero feedback loop. Engineers have no incentive or mechanism to rightsize their workloads.

---

## Why This Matters More in 2026

- **Cloud cost accountability is now an engineering KPI** at most mid-to-large tech companies. FinOps teams exist specifically to bridge the gap between engineering and finance.
- **Kubernetes adoption has peaked** — most teams are no longer in "getting it to work" mode. The next frontier is efficiency.
- **Azure VM costs are not declining** — DS/ES series nodes for AKS are expensive. Waste at 30% average utilization (industry average per CNCF 2024 survey) on a $10,000/month AKS bill is $3,000/month thrown away.
- **FinOps Foundation Framework** (adopted by major enterprises) mandates cost allocation, showback, and rightsizing as core practices — yet most AKS deployments have none of these.

---

## What Does "Good" Look Like?

A team with healthy Kubernetes cost practices can answer these questions in under 5 minutes:

1. Which namespace spent the most this week?
2. Which deployment has the largest gap between requested and actual CPU?
3. Are there any workloads that haven't received traffic in 7+ days?
4. What would happen to our bill if we accepted all current VPA recommendations?
5. Who do we alert when a new deployment ships with oversized requests?

This toolkit makes all five questions answerable — without proprietary tooling, without a FinOps vendor contract, and without leaving your existing Prometheus + Grafana stack.

---

## What This Toolkit Does NOT Solve

Being explicit about scope prevents scope creep and sets accurate expectations:

- **Multi-cloud cost attribution** — this is AKS-specific
- **Chargeback/showback accounting** — use OpenCost or Kubecost for dollar-accurate showback (Phase 2 roadmap item)
- **Automatic rightsizing** — VPA is deployed in recommendation mode only; auto-apply carries production risk
- **Network egress costs** — out of scope for MVP
- **Spot/preemptible node optimization** — separate concern, separate toolkit

---

## References

- [CNCF FinOps for Kubernetes Whitepaper](https://www.cncf.io/reports/kubernetes-finops/)
- [Fairwinds Goldilocks (VPA UI)](https://github.com/FairwindsOps/goldilocks)
- [Azure Cost Management for AKS](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/allocate-costs)
- [FinOps Foundation: Kubernetes Cost Allocation](https://www.finops.org/wg/calculating-container-costs/)
