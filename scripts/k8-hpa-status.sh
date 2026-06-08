#!/usr/bin/env bash
# One-shot pods + HPA + CPU (for load-test snapshots).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/bin:${PATH:-}"
# shellcheck source=lib/kind-common.sh
source "$ROOT/scripts/lib/kind-common.sh"

NS="${CXR_K8_NAMESPACE:-cxr-ui}"
require_kubectl "$ROOT"

echo "== pods + HPA ($NS) =="
kubectl get pods,hpa -n "$NS"
echo ""
echo "== CPU (metrics-server) =="
kubectl top pods -n "$NS" 2>/dev/null || echo "metrics not ready yet"
