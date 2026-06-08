#!/usr/bin/env bash
# Full CXR K8 stack: kind + UI + analyzer + HPA + metrics-server.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/bin:${PATH:-}"

echo "==> kind cluster (host.docker.internal for SQL/Qdrant)"
"$ROOT/scripts/01-kind-cluster.sh"

echo "==> build + load cxr-ui:local"
"$ROOT/scripts/02-build-and-load.sh"

if [[ "${CXR_SKIP_ANALYZER_BUILD:-0}" != "1" ]]; then
  echo "==> build + load cxr-analyzer:local"
  "$ROOT/scripts/02-build-analyzer-and-load.sh"
else
  echo "==> skipping analyzer build (CXR_SKIP_ANALYZER_BUILD=1)"
fi

echo "==> Helm stack (analyzer + UI + HPA)"
"$ROOT/scripts/06-helm-install-stack.sh"

echo ""
echo "CXR Kubernetes stack is up (UI + analyzer + HPA)."
echo "  ./scripts/16-k8-stack-verify.sh     # pods + analyzer + :8081 (no bind error)"
echo "  ./scripts/k8-ui-forward.sh check    # :8081 already up? (systemd cxr-k8-forward OK)"
echo "  kubectl get all,hpa -n cxr-ui"
echo "  http://localhost:8081  (Claim Studio via in-cluster analyzer)"
echo "  ./scripts/k8-hpa-status.sh           # pods + HPA snapshot"
echo "  ./scripts/k8-hpa-watch.sh            # live pods + HPA (not: kubectl get hpa,pods -w)"
echo "  kubectl get hpa -n cxr-ui -w         # HPA replicas only"
echo "  Docs: $ROOT/docs/K8-STACK-DEPLOY.md"
