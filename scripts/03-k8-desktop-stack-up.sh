#!/usr/bin/env bash
# Full CXR K8 stack on Docker Desktop Kubernetes (no kind).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/bin:${PATH:-}"
export CXR_K8_RUNTIME=docker-desktop

echo "==> Docker Desktop Kubernetes (context docker-desktop)"
"$ROOT/scripts/00-k8-desktop-enable.sh"

if [[ "${CXR_RETIRE_KIND:-1}" == "1" ]] && kind get clusters 2>/dev/null | grep -qx 'cxr-lab'; then
  echo "==> Removing legacy kind cluster cxr-lab (avoid dual clusters)"
  kind delete cluster --name cxr-lab || true
  docker rm -f cxr-lab-control-plane cxr-lab-worker cxr-lab-worker2 2>/dev/null || true
fi

echo "==> build cxr-ui:local (skip kind load — same Docker daemon)"
if [[ "${CXR_SKIP_UI_BUILD:-0}" != "1" ]]; then
  UI_SRC="${CXR_UI_SRC:-$ROOT/../cxr-ui-prune-rehearsal/cxr-ui}"
  docker build -t cxr-ui:local -f "$ROOT/docker/ui/Dockerfile" "$UI_SRC"
else
  echo "  skipping UI build (CXR_SKIP_UI_BUILD=1)"
fi

if [[ "${CXR_SKIP_ANALYZER_BUILD:-0}" != "1" ]]; then
  echo "==> build cxr-analyzer:local"
  "$ROOT/scripts/02-build-analyzer-docker-only.sh"
else
  echo "==> skipping analyzer build (CXR_SKIP_ANALYZER_BUILD=1)"
fi

echo "==> Helm stack (analyzer + UI + HPA)"
CXR_K8_RUNTIME=docker-desktop "$ROOT/scripts/06-helm-install-stack.sh"

echo ""
echo "CXR stack on Docker Desktop Kubernetes."
echo "  ./scripts/16-k8-stack-verify.sh"
echo "  ./scripts/k8-hpa-watch.sh"
echo "  http://localhost:8081"
