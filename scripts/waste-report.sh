#!/usr/bin/env bash
# waste-report.sh
# Prints a formatted Kubernetes resource waste summary to the terminal.
# Requires: kubectl, jq, bc
# No cluster changes are made — read-only.

set -euo pipefail

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

NAMESPACE="${1:-}"  # Optional: filter by namespace

echo ""
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${CYAN}║         AKS FinOps Toolkit — Waste Report                ║${RESET}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════════╝${RESET}"
echo -e "  Context: ${BOLD}$(kubectl config current-context)${RESET}"
echo -e "  Time:    $(date -u '+%Y-%m-%d %H:%M UTC')"
echo ""

# ─────────────────────────────────────────────
# Namespace summary
# ─────────────────────────────────────────────
echo -e "${BOLD}── Namespaces ────────────────────────────────────────────────${RESET}"

NS_ARGS=""
if [[ -n "$NAMESPACE" ]]; then
  NS_ARGS="-n $NAMESPACE"
  echo -e "   Filtering: ${YELLOW}${NAMESPACE}${RESET}"
else
  NS_ARGS="--all-namespaces"
fi

# Get all pods with resource requests
kubectl get pods $NS_ARGS -o json 2>/dev/null | jq -r '
  .items[]
  | . as $pod
  | ($pod.metadata.namespace) as $ns
  | ($pod.metadata.name) as $name
  | ($pod.status.phase) as $phase
  | select($phase == "Running")
  | .spec.containers[]
  | {
      namespace: $ns,
      pod: $name,
      container: .name,
      cpu_req: ((.resources.requests.cpu // "0m") | gsub("m"; "") | tonumber // 0),
      mem_req: ((.resources.requests.memory // "0Mi") |
        if test("Gi") then gsub("Gi";"") | tonumber * 1024
        elif test("Mi") then gsub("Mi";"") | tonumber
        elif test("Ki") then gsub("Ki";"") | tonumber / 1024
        else tonumber / 1048576 end)
    }
' 2>/dev/null | jq -s '
  group_by(.namespace)
  | map({
      namespace: .[0].namespace,
      pods: length,
      total_cpu_req_m: map(.cpu_req) | add,
      total_mem_req_mi: map(.mem_req) | add
    })
  | sort_by(.total_cpu_req_m)
  | reverse
' 2>/dev/null | jq -r '
  .[]
  | "  \(.namespace | .[0:30] | . + " " * (30 - length))  pods: \(.pods | tostring | .[0:4] | . + " " * (4 - length))  CPU req: \(.total_cpu_req_m | tostring)m  MEM req: \(.total_mem_req_mi | floor | tostring)Mi"
' 2>/dev/null || echo -e "  ${YELLOW}Could not retrieve pod resource data. Is kubectl configured?${RESET}"

echo ""

# ─────────────────────────────────────────────
# VPA Recommendations summary
# ─────────────────────────────────────────────
echo -e "${BOLD}── VPA Recommendations ───────────────────────────────────────${RESET}"

VPA_NS_ARGS=""
if [[ -n "$NAMESPACE" ]]; then
  VPA_NS_ARGS="-n $NAMESPACE"
else
  VPA_NS_ARGS="--all-namespaces"
fi

VPA_COUNT=$(kubectl get vpa $VPA_NS_ARGS --no-headers 2>/dev/null | wc -l | tr -d ' ')

if [[ "$VPA_COUNT" -eq 0 ]]; then
  echo -e "  ${YELLOW}No VPA objects found. Deploy VPA objects from manifests/vpa/.${RESET}"
else
  echo -e "  Found ${BOLD}${VPA_COUNT}${RESET} VPA object(s)"
  echo ""
  kubectl get vpa $VPA_NS_ARGS -o json 2>/dev/null | jq -r '
    .items[]
    | . as $vpa
    | ($vpa.metadata.namespace) as $ns
    | ($vpa.metadata.name) as $name
    | ($vpa.status.recommendation.containerRecommendations // [])
    | .[]
    | "  \($ns)/\($name)/\(.containerName)\n    Target CPU: \(.target.cpu // "n/a")  Target Memory: \(.target.memory // "n/a")\n    Lower:  CPU: \(.lowerBound.cpu // "n/a")  Memory: \(.lowerBound.memory // "n/a")\n    Upper:  CPU: \(.upperBound.cpu // "n/a")  Memory: \(.upperBound.memory // "n/a")"
  ' 2>/dev/null || echo -e "  ${YELLOW}VPA recommendations not yet available. Wait 10-30 minutes after deployment.${RESET}"
fi

echo ""

# ─────────────────────────────────────────────
# Zombie namespace candidates
# ─────────────────────────────────────────────
echo -e "${BOLD}── Zombie Namespace Candidates ───────────────────────────────${RESET}"
echo -e "  ${CYAN}(namespaces with pods but excluded from system namespaces)${RESET}"

SYSTEM_NS="kube-system|monitoring|vpa-system|kube-public|default|gatekeeper-system|cert-manager"

kubectl get ns -o json 2>/dev/null | jq -r --arg sys "$SYSTEM_NS" '
  .items[]
  | select(.metadata.name | test($sys) | not)
  | .metadata.name
' 2>/dev/null | while read -r ns; do
  POD_COUNT=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$POD_COUNT" -gt 0 ]]; then
    AGE=$(kubectl get ns "$ns" -o jsonpath='{.metadata.creationTimestamp}' 2>/dev/null)
    echo -e "  ${YELLOW}${ns}${RESET} — ${POD_COUNT} pod(s) — created: ${AGE}"
  fi
done || echo -e "  ${GREEN}No obvious zombie namespaces detected.${RESET}"

echo ""
echo -e "${BOLD}── Tips ──────────────────────────────────────────────────────${RESET}"
echo -e "  • Check Grafana dashboards for full waste breakdown:"
echo -e "    ${CYAN}kubectl port-forward svc/aks-finops-toolkit-grafana 3000:80 -n monitoring${RESET}"
echo -e "  • View VPA detail: ${CYAN}kubectl describe vpa <name> -n <namespace>${RESET}"
echo -e "  • Full docs: https://github.com/your-username/aks-finops-toolkit"
echo ""
