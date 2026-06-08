#!/usr/bin/env bash
# Watch pods + HPA together (kubectl --watch allows only one resource type).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/bin:${PATH:-}"
# shellcheck source=lib/kind-common.sh
source "$ROOT/scripts/lib/kind-common.sh"

NS="${CXR_K8_NAMESPACE:-cxr-ui}"
INTERVAL="${CXR_HPA_WATCH_INTERVAL:-2}"

ensure_k8_context "$ROOT"
echo "Cluster: $(kubectl config current-context) ($(cxr_k8_runtime))"
require_kubectl "$ROOT"

if ! command -v watch &>/dev/null; then
  echo "watch not found — install procps, or run:" >&2
  echo "  kubectl get hpa -n $NS -w    # replica changes only" >&2
  echo "  kubectl get pods,hpa -n $NS  # one-shot snapshot" >&2
  exit 1
fi

exec watch -n "$INTERVAL" "kubectl get pods,hpa -n $NS; echo; kubectl top pods -n $NS 2>/dev/null || echo '(metrics: wait for metrics-server)'"
