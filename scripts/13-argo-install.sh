#!/usr/bin/env bash
# SW.8 — Install Argo CD on kind cxr-lab (bootcamp GitOps lab).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/bin:${PATH:-}"

if ! kubectl cluster-info --context "kind-${CXR_KIND_CLUSTER:-cxr-lab}" &>/dev/null; then
  echo "kind cluster not ready; run ./scripts/03-k8-up.sh first" >&2
  exit 1
fi

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

echo "Applying Application from Git: $CXR_ARGO_REPO_URL ($CXR_ARGO_REPO_REVISION)"
envsubst '$CXR_ARGO_REPO_URL $CXR_ARGO_REPO_REVISION' < "$ROOT/k8s/argocd/application-cxr-ui.yaml" | kubectl apply -f -

for _ in $(seq 1 36); do
  sync=$(kubectl get application cxr-ui -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "")
  health=$(kubectl get application cxr-ui -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "")
  [[ "$sync" == "Synced" && "$health" == "Healthy" ]] && break
  kubectl annotate application cxr-ui -n argocd argocd.argoproj.io/refresh=hard --overwrite 2>/dev/null || true
  sleep 5
done
kubectl get application cxr-ui -n argocd
