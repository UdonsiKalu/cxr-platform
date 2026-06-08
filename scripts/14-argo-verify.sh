#!/usr/bin/env bash
# Verify Argo CD apps cxr-ui + cxr-analyzer are Synced/Healthy.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/bin:${PATH:-}"
# shellcheck source=lib/kind-common.sh
source "$ROOT/scripts/lib/kind-common.sh"

require_kubectl "$ROOT"
FAIL=0
pass() { echo "  [OK] $*"; }
fail() { echo "  [FAIL] $*"; FAIL=1; }

echo "=== Argo CD verify (GITOPS-001) ==="
echo "Cluster: $(kubectl config current-context) ($(cxr_k8_runtime))"
echo ""

for app in cxr-ui cxr-analyzer; do
  if ! kubectl get application "$app" -n argocd &>/dev/null; then
    fail "Application $app missing in argocd namespace"
    continue
  fi
  sync=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "")
  health=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "")
  echo "-- $app: sync=$sync health=$health"
  [[ "$sync" == "Synced" ]] && pass "$app Synced" || fail "$app not Synced ($sync)"
  [[ "$health" == "Healthy" ]] && pass "$app Healthy" || fail "$app not Healthy ($health)"
done

echo ""
if [[ "$FAIL" -eq 0 ]]; then
  echo "ALL PASSED"
else
  echo "SOME CHECKS FAILED — kubectl get application -n argocd"
  exit 1
fi
