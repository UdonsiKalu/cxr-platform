#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/bin:${PATH:-}"
CHART="$ROOT/helm/cxr-ui"
NS="${CXR_K8_NAMESPACE:-cxr-ui}"

if ! command -v helm &>/dev/null; then
  echo "helm not found; run $ROOT/scripts/00-install-tools.sh" >&2
  exit 1
fi

# Adopt namespace/deployment from prior raw `kubectl apply` (SW.3 study path).
if kubectl get namespace "$NS" &>/dev/null; then
  if ! kubectl get namespace "$NS" -o jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}' 2>/dev/null | grep -qx Helm; then
    echo "Adopting existing namespace $NS for Helm..."
    kubectl label namespace "$NS" app.kubernetes.io/managed-by=Helm --overwrite
    kubectl annotate namespace "$NS" \
      meta.helm.sh/release-name=cxr-ui \
      meta.helm.sh/release-namespace="$NS" \
      --overwrite
  fi
  if kubectl get deployment -n "$NS" cxr-ui &>/dev/null; then
    managed=$(kubectl get deployment -n "$NS" cxr-ui -o jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}' 2>/dev/null || true)
    if [[ "$managed" != "Helm" ]]; then
      echo "Removing pre-Helm deployment/service (raw SW.3 manifests)..."
      kubectl delete deployment,service -n "$NS" cxr-ui --ignore-not-found
    fi
  fi
fi

helm upgrade --install cxr-ui "$CHART" \
  -n "$NS" \
  --create-namespace \
  --wait \
  --timeout 3m

kubectl get all -n "$NS"
helm list -n "$NS"
