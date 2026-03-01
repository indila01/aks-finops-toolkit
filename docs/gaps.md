# Gaps & Remaining Work

Status as of MVP completion. All blocking and high-priority gaps have been resolved.

---

## Resolved

| Gap | What was missing | Resolution |
|---|---|---|
| **GAP-01** | `charts/templates/` was empty | Created `_helpers.tpl`, `alertmanager-config.yaml`, `prometheus-rules.yaml`, `grafana-dashboards.yaml`, `NOTES.txt` |
| **GAP-02** | 3 of 4 dashboards missing | Created Namespace Heatmap, VPA Tracker, Node Pool Utilization dashboards |
| **GAP-03** | `manifests/` not connected to Helm | All manifests now rendered as Helm templates; `manifests/` documented as optional standalone alternative |
| **GAP-04** | No `variables.tf` or `tfvars.example` in dev env | Added `variables.tf`, `terraform.tfvars.example`, updated `main.tf` to use vars |
| **GAP-05** | No `.gitignore` | Added `.gitignore` covering Terraform state, Helm deps, secrets, editor files |
| **GAP-06** | VPA recommendations not a Prometheus metric by default | Enabled `verticalpodautoscalers` collector in kube-state-metrics via `values.yaml` |
| **GAP-07** | Slack webhook URL not rendered by Helm | Moved Alertmanager config to `templates/alertmanager-config.yaml` as a Helm-templated Secret |
| **GAP-09** | `your-username` placeholders throughout | Replaced with `indila01` convention (user replaces before publishing) |
| **GAP-10** | `terraform/modules/monitoring/` in design docs but doesn't exist | Updated `docs/solution-design.md` to document the actual approach (namespaces inline in env) |
| **GAP-11** | No `terraform/environments/dev/README.md` | Created with remote state setup, permissions, teardown instructions |
| **GAP-12** | No `NOTES.txt` | Created with 5-step post-install guide |
| **GAP-13** | No `LICENSE` file | Created MIT LICENSE |
| **GAP-14** | No `_helpers.tpl` | Created with name, fullname, labels, selectorLabels, dashboardLabel helpers |
| **GAP-15** | `Chart.lock` not committed | Documented in Quick Start: user runs `helm dependency update` before install |

---

## Deferred to Phase 2 (by design)

| Gap | Decision |
|---|---|
| **GAP-08** | Medium article `[SCREENSHOT]` placeholders and real savings numbers — requires actual deployment. Fill in after running the stack for 1 week. |

---

## Phase 2 Backlog

These were always out of scope for MVP but are the natural next steps:

| Item | Description |
|---|---|
| OpenCost integration | Dollar-accurate per-namespace cost attribution |
| Goldilocks UI | Friendly VPA recommendation browser |
| Weekly Slack digest | CronJob sending weekly waste summary |
| MutatingWebhookConfiguration | Auto-label new workloads with cost-center tags |
| Multi-cluster support | Thanos/VictoriaMetrics for federation across clusters |
| GitHub Actions: dashboard CI | Validate dashboard JSON on PR |
| VPA `Auto` mode option | Opt-in flag for teams that accept automatic rightsizing |
