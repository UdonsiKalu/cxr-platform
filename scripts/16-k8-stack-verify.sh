#!/usr/bin/env bash
# Verify K8 stack (UI + analyzer + HPA) and ensure :8081 is reachable without bind errors.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/bin:${PATH:-}"
# shellcheck source=lib/kind-common.sh
source "$ROOT/scripts/lib/kind-common.sh"

NS="${CXR_K8_NAMESPACE:-cxr-ui}"
FAIL=0

pass() { echo "  [OK] $*"; }
fail() { echo "  [FAIL] $*"; FAIL=1; }

ensure_k8_context "$ROOT"
echo "Cluster: $(kubectl config current-context) ($(cxr_k8_runtime))"
require_kubectl "$ROOT"

echo "=== CXR K8 stack verify (UI + analyzer + HPA) ==="
echo ""

echo "-- Pods + HPA"
kubectl get pods,hpa -n "$NS"
echo ""

echo "-- Analyzer /health/ready"
if kubectl exec -n "$NS" deploy/cxr-analyzer -- curl -sf http://127.0.0.1:8766/health/ready; then
  echo ""
  pass "analyzer warmed"
else
  fail "analyzer not ready"
fi
echo ""

echo "-- UI :8081 (idempotent forward — no bind error if already up)"
if "$ROOT/scripts/k8-ui-forward.sh" check; then
  pass "UI http://127.0.0.1:8081/"
else
  echo "  Attempting background forward..."
  if "$ROOT/scripts/k8-ui-forward.sh" --background; then
    pass "UI http://127.0.0.1:8081/ (started)"
  else
    fail "UI :8081 not reachable"
  fi
fi

code=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 3 http://127.0.0.1:8081/ 2>/dev/null || echo "000")
if [[ "$code" == "200" ]]; then
  pass "HTTP GET / → $code"
else
  fail "HTTP GET / → $code"
fi

echo ""
if [[ "$FAIL" -eq 0 ]]; then
  echo "ALL PASSED — open http://127.0.0.1:8081"
  exit 0
fi
echo "SOME CHECKS FAILED"
exit 1
