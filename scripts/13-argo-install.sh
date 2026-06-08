#!/usr/bin/env bash
# SW.8 — Install Argo CD (Docker Desktop K8 or kind).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/bin:${PATH:-}"
# shellcheck source=lib/kind-common.sh
source "$ROOT/scripts/lib/kind-common.sh"

require_kubectl "$ROOT"
echo "Argo CD target cluster: $(kubectl config current-context) ($(cxr_k8_runtime))"

if ! command -v helm &>/dev/null; then
  echo "helm not found; run $ROOT/scripts/00-install-tools.sh" >&2
  exit 1
fi

helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update argo

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install argocd argo/argo-cd \
  -n argocd \
  --wait \
  --timeout 10m \
  --set server.service.type=ClusterIP

echo ""
echo "Argo CD installed in namespace argocd."
echo "  UI (port-forward): kubectl port-forward svc/argocd-server -n argocd 8083:443"
echo "  https://localhost:8083  (accept self-signed cert)"
echo "  Initial admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || echo "  (secret not ready yet — wait and re-run)"
echo ""
echo ""

export CXR_ARGO_REPO_URL="${CXR_ARGO_REPO_URL:-https://github.com/UdonsiKalu/cxr-ops-lab.git}"
export CXR_ARGO_REPO_REVISION="${CXR_ARGO_REPO_REVISION:-main}"

TOKEN=""
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  TOKEN="$GITHUB_TOKEN"
elif command -v gh &>/dev/null; then
  TOKEN="$(gh auth token 2>/dev/null || true)"
fi
if [[ -n "$TOKEN" ]]; then
  kubectl create secret generic repo-cxr-ops-lab -n argocd \
    --from-literal=type=git \
    --from-literal=url="$CXR_ARGO_REPO_URL" \
    --from-literal=username=git \
    --from-literal=password="$TOKEN" \
    --dry-run=client -o yaml | kubectl apply -f -
  kubectl label secret repo-cxr-ops-lab -n argocd \
    argocd.argoproj.io/secret-type=repository --overwrite
fi

echo "Applying Applications from Git: $CXR_ARGO_REPO_URL ($CXR_ARGO_REPO_REVISION)"
for manifest in application-cxr-analyzer.yaml application-cxr-ui.yaml; do
  envsubst '$CXR_ARGO_REPO_URL $CXR_ARGO_REPO_REVISION' < "$ROOT/k8s/argocd/$manifest" | kubectl apply -f -
done

wait_app() {
  local app="$1"
  for _ in $(seq 1 36); do
    sync=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "")
    health=$(kubectl get application "$app" -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "")
    [[ "$sync" == "Synced" && "$health" == "Healthy" ]] && return 0
    kubectl annotate application "$app" -n argocd argocd.argoproj.io/refresh=hard --overwrite 2>/dev/null || true
    sleep 5
  done
  return 1
}

for app in cxr-analyzer cxr-ui; do
  echo "Waiting for $app..."
  wait_app "$app" || echo "WARN: $app not Synced/Healthy yet (analyzer warm boot may take 7–15m)"
done
kubectl get application -n argocd
echo ""
echo "Verify: $ROOT/scripts/14-argo-verify.sh"
echo "GitOps loop: edit helm/*/values.yaml → git push → Argo syncs"
