#!/usr/bin/env bash
# End-to-end: Terraform (kind) → build/load image → Helm baseline → Argo CD (Git) → probes
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/bin:${PATH:-}"
CLUSTER="${CXR_KIND_CLUSTER:-cxr-lab}"
CTX="kind-${CLUSTER}"
REPO_URL="${CXR_ARGO_REPO_URL:-https://github.com/UdonsiKalu/cxr-ops-lab.git}"
LOG="/tmp/cxr-e2e-$$.log"

log() { echo "==> $*" | tee -a "$LOG"; }

"$ROOT/scripts/00-install-tools.sh" | tee -a "$LOG"

log "SW.5 Terraform — provision kind cluster"
terraform -chdir="$ROOT/terraform" init -input=false | tee -a "$LOG"
terraform -chdir="$ROOT/terraform" apply -input=false -auto-approve | tee -a "$LOG"

log "Ensure kind node is running"
if docker inspect cxr-lab-control-plane &>/dev/null; then
  docker start cxr-lab-control-plane 2>/dev/null || true
  for _ in $(seq 1 60); do
    kubectl --context "$CTX" cluster-info &>/dev/null && break
    sleep 2
  done
fi

log "SW.1–4 — load image + Helm (12-k8-ensure)"
"$ROOT/scripts/12-k8-ensure.sh" | tee -a "$LOG"

log "SW.8 Argo CD + Application from GitHub"
export CXR_ARGO_REPO_URL="$REPO_URL"
export CXR_ARGO_REPO_REVISION="${CXR_ARGO_REPO_REVISION:-main}"
"$ROOT/scripts/13-argo-install.sh" | tee -a "$LOG"

log "Port-forwards (background)"
fuser -k 8081/tcp 8083/tcp 2>/dev/null || true
sleep 1
kubectl --context "$CTX" port-forward -n cxr-ui svc/cxr-ui 8081:3000 --address=127.0.0.1 >>"$LOG" 2>&1 &
PF_CXR=$!
kubectl --context "$CTX" port-forward -n argocd svc/argocd-server 8083:443 --address=127.0.0.1 >>"$LOG" 2>&1 &
PF_ARGO=$!
sleep 3

log "Integration test"
"$ROOT/scripts/14-stack-test.sh" | tee -a "$LOG"
TEST_EXIT=${PIPESTATUS[0]:-$?}

echo ""
echo "=== E2E deploy complete ==="
echo "  CXR UI:    http://localhost:8081"
echo "  Argo CD:   https://localhost:8083  (admin password below)"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || true
echo ""
echo "  Log: $LOG"
echo "  Port-forward PIDs: cxr=$PF_CXR argo=$PF_ARGO (kill to stop)"
echo ""
kubectl --context "$CTX" get application cxr-ui -n argocd
kubectl --context "$CTX" get pods -n cxr-ui
kubectl --context "$CTX" get pods -n argocd | head -10

exit "$TEST_EXIT"
