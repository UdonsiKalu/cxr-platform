#!/usr/bin/env bash
# End-to-end test: Terraform context → kind → Helm → Argo → CXR UI on :8081
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/bin:${PATH:-}"
CLUSTER="${CXR_KIND_CLUSTER:-cxr-lab}"
CTX="kind-${CLUSTER}"
FAIL=0

pass() { echo "  [OK] $*"; }
fail() { echo "  [FAIL] $*"; FAIL=1; }

echo "=== CXR K8 stack integration test ==="
echo "Context: $CTX"
echo ""

echo "-- Terraform (SW.5)"
if command -v terraform &>/dev/null && [[ -f "$ROOT/terraform/terraform.tfstate" ]]; then
  kube_ctx=$(terraform -chdir="$ROOT/terraform" output -raw kube_context 2>/dev/null || true)
  if [[ "$kube_ctx" == "$CTX" ]]; then
    pass "terraform output kube_context=$kube_ctx"
  else
    fail "terraform kube_context=$kube_ctx (expected $CTX)"
  fi
else
  echo "  [SKIP] terraform state not found (run: cd terraform && terraform apply)"
fi

echo ""
echo "-- Cluster + workloads"
if kubectl --context "$CTX" cluster-info &>/dev/null; then
  pass "kind cluster API"
else
  fail "kind cluster API"
fi

for ns in cxr-ui argocd; do
  if kubectl --context "$CTX" get namespace "$ns" &>/dev/null; then
    pass "namespace $ns"
  else
    fail "namespace $ns missing"
  fi
done

if kubectl --context "$CTX" get deployment -n cxr-ui cxr-ui &>/dev/null; then
  ready=$(kubectl --context "$CTX" get deployment -n cxr-ui cxr-ui -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
  if [[ "${ready:-0}" -ge 1 ]]; then
    pass "deployment/cxr-ui ready ($ready)"
  else
    fail "deployment/cxr-ui not ready"
  fi
else
  fail "deployment/cxr-ui missing"
fi

echo ""
echo "-- Helm releases"
while read -r line; do
  [[ -n "$line" ]] && pass "helm: $line"
done < <(helm list -A --kube-context "$CTX" 2>/dev/null | tail -n +2 | awk '{print $1"/"$2" "$8}')

echo ""
echo "-- Argo CD (SW.8)"
if kubectl --context "$CTX" get deployment -n argocd argocd-server &>/dev/null; then
  pass "argocd-server deployment"
else
  fail "argocd-server missing"
fi

if kubectl --context "$CTX" get application cxr-ui -n argocd &>/dev/null; then
  sync=$(kubectl --context "$CTX" get application cxr-ui -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "?")
  health=$(kubectl --context "$CTX" get application cxr-ui -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "?")
  if [[ "$sync" == "Synced" && "$health" == "Healthy" ]]; then
    pass "argocd application/cxr-ui sync=$sync health=$health"
  else
    fail "argocd application/cxr-ui sync=$sync health=$health"
  fi
else
  fail "argocd application/cxr-ui missing"
fi

echo ""
echo "-- HTTP probes (host)"
code=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 2 http://127.0.0.1:8081/ 2>/dev/null || echo "000")
if [[ "$code" == "200" ]]; then
  pass "CXR UI http://localhost:8081 → $code"
else
  fail "CXR UI :8081 → $code (run: kubectl port-forward -n cxr-ui svc/cxr-ui 8081:3000)"
fi

code=$(curl -sk -o /dev/null -w '%{http_code}' --connect-timeout 2 https://127.0.0.1:8083/ 2>/dev/null || echo "000")
if [[ "$code" =~ ^(200|302)$ ]]; then
  pass "Argo CD UI https://localhost:8083 → $code"
else
  echo "  [WARN] Argo UI :8083 → $code (start: kubectl port-forward svc/argocd-server -n argocd 8083:443)"
fi

echo ""
kubectl --context "$CTX" get pods -A 2>/dev/null | grep -E 'cxr-ui|argocd' || true

echo ""
if [[ "$FAIL" -eq 0 ]]; then
  echo "=== ALL CHECKS PASSED ==="
  exit 0
fi
echo "=== SOME CHECKS FAILED ==="
exit 1
