#!/usr/bin/env bash
# SCALE-003 — VPA recommender only (no auto-apply). Generates kubectl describe recommendations.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/bin:${PATH:-}"
# shellcheck source=lib/kind-common.sh
source "$ROOT/scripts/lib/kind-common.sh"

NS="${CXR_VPA_NAMESPACE:-kube-system}"
require_kubectl "$ROOT"

if ! command -v helm &>/dev/null; then
  echo "helm required — run scripts/00-install-tools.sh" >&2
  exit 1
fi

if kubectl get crd verticalpodautoscalers.autoscaling.k8s.io &>/dev/null; then
  echo "VPA CRD already installed"
  kubectl get pods -n "$NS" -l app.kubernetes.io/name=vpa 2>/dev/null | head -5 || true
  exit 0
fi

echo "==> Installing VPA (recommender only — updateMode Off on CXR VPA objects)"
helm repo add fairwinds-stable https://charts.fairwinds.com/stable 2>/dev/null || true
helm repo update fairwinds-stable
helm upgrade --install vpa fairwinds-stable/vpa \
  --namespace "$NS" \
  --set recommender.enabled=true \
  --set updater.enabled=false \
  --set admissionController.enabled=false \
  --wait \
  --timeout 5m

echo "VPA recommender ready — helm autoscaling.vpa.enabled on cxr-analyzer"
