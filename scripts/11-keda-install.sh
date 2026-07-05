#!/usr/bin/env bash
# SCALE-001 — Install KEDA for Prometheus + CPU scaled objects.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/bin:${PATH:-}"
# shellcheck source=lib/kind-common.sh
source "$ROOT/scripts/lib/kind-common.sh"

NS="${CXR_KEDA_NAMESPACE:-keda}"
require_kubectl "$ROOT"

if ! command -v helm &>/dev/null; then
  echo "helm required — run scripts/00-install-tools.sh" >&2
  exit 1
fi

if kubectl get crd scaledobjects.keda.sh &>/dev/null; then
  echo "KEDA already installed (scaledobjects.keda.sh)"
  kubectl get pods -n "$NS" 2>/dev/null || kubectl get pods -A -l app=keda-operator 2>/dev/null | head -5
  exit 0
fi

echo "==> Installing KEDA in namespace $NS"
helm repo add kedacore https://kedacore.github.io/charts 2>/dev/null || true
helm repo update kedacore
helm upgrade --install keda kedacore/keda \
  --namespace "$NS" \
  --create-namespace \
  --wait \
  --timeout 5m

echo "KEDA ready — enable autoscaling.keda.enabled in helm/cxr-analyzer/values.yaml"
