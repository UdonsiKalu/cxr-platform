#!/usr/bin/env bash
# SW.3 + SW.4 one-shot: kind cluster, build/load image, Helm deploy.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/bin:${PATH:-}"

echo "==> kind cluster"
"$ROOT/scripts/01-kind-cluster.sh"

echo "==> build + load cxr-ui:local"
"$ROOT/scripts/02-build-and-load.sh"

echo "==> Helm deploy (SW.4)"
"$ROOT/scripts/05-helm-install.sh"

echo ""
echo "CXR on Kubernetes is up."
echo "  kubectl get all -n cxr-ui"
echo "  kubectl port-forward -n cxr-ui svc/cxr-ui 8081:3000 --address=127.0.0.1"
echo "  http://localhost:8081"
echo "  Docs: $ROOT/docs/K8-DEPLOY.md"
