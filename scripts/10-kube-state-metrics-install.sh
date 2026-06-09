#!/usr/bin/env bash
# Install kube-state-metrics (Prometheus/Grafana: HPA replicas, Pending pods).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/bin:${PATH:-}"
# shellcheck source=lib/kind-common.sh
source "$ROOT/scripts/lib/kind-common.sh"

require_kubectl "$ROOT"
KSM_VERSION="${CXR_KSM_VERSION:-v2.13.0}"
BASE="https://raw.githubusercontent.com/kubernetes/kube-state-metrics/${KSM_VERSION}/examples/standard"

if kubectl get deployment kube-state-metrics -n kube-system &>/dev/null; then
  echo "kube-state-metrics already installed in kube-system"
else
  echo "Installing kube-state-metrics ${KSM_VERSION}..."
  kubectl apply -f "${BASE}/service-account.yaml"
  kubectl apply -f "${BASE}/cluster-role.yaml"
  kubectl apply -f "${BASE}/cluster-role-binding.yaml"
  kubectl apply -f "${BASE}/deployment.yaml"
  kubectl apply -f "${BASE}/service.yaml"
fi

kubectl rollout status deployment/kube-state-metrics -n kube-system --timeout=120s
echo "kube-state-metrics ready — scrape via scripts/k8-ksm-port-forward.sh"
