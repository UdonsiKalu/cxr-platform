#!/usr/bin/env bash
# Deploy full CXR stack: analyzer + UI + HPA (SW.4 + autoscaling).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/bin:${PATH:-}"
# shellcheck source=lib/kind-common.sh
source "$ROOT/scripts/lib/kind-common.sh"
NS="${CXR_K8_NAMESPACE:-cxr-ui}"
ANALYZER_TIMEOUT="${CXR_ANALYZER_HELM_TIMEOUT:-15m}"
UI_TIMEOUT="${CXR_UI_HELM_TIMEOUT:-5m}"
HOST_VALUES="$(mktemp /tmp/cxr-analyzer-host-XXXXXX.yaml)"
trap 'rm -f "$HOST_VALUES"' EXIT

if ! command -v helm &>/dev/null; then
  echo "helm not found; run $ROOT/scripts/00-install-tools.sh" >&2
  exit 1
fi

require_kubectl "$ROOT"

ensure_namespace() {
  if ! kubectl get namespace "$NS" &>/dev/null; then
    echo "Creating namespace $NS (shared by cxr-analyzer + cxr-ui releases)..."
    kubectl create namespace "$NS"
  fi
}

host_gateway_ip() {
  if [[ -n "${CXR_HOST_IP:-}" ]]; then
    echo "$CXR_HOST_IP"
    return
  fi
  if [[ "$(cxr_k8_runtime)" == "docker-desktop" ]]; then
    echo "host.docker.internal"
    return
  fi
  local kind_node="cxr-lab-control-plane"
  if docker inspect "$kind_node" &>/dev/null; then
    # kind nodes resolve host.docker.internal; SQL is reachable there (not via eth0 default gw).
    if docker exec "$kind_node" getent hosts host.docker.internal &>/dev/null; then
      echo "host.docker.internal"
      return
    fi
    docker exec "$kind_node" ip -4 route show default 2>/dev/null | awk '{print $3}' | head -1 && return
  fi
  if [[ -f /tmp/cxr-kind-host-ip ]]; then
    cat /tmp/cxr-kind-host-ip
    return
  fi
  echo "host.docker.internal"
}

HOST_IP="$(host_gateway_ip)"
if [[ -z "$HOST_IP" ]]; then
  HOST_IP="172.17.0.1"
fi
echo "Host gateway for analyzer pods: $HOST_IP (SQL :1433, Qdrant :6333)"

cat >"$HOST_VALUES" <<EOF
env:
  CXR_SQL_SERVER: "${HOST_IP},1433"
  CXR_QDRANT_URL: "http://${HOST_IP}:6333"
EOF

echo "==> metrics-server (HPA prerequisite)"
"$ROOT/scripts/09-metrics-server-install.sh"

ensure_namespace

echo "==> Helm: cxr-analyzer (may wait for warm startup probes)..."
# Analyzer warm boot is 7–15m — do not block Helm on --wait (use 16-k8-stack-verify.sh).
helm upgrade --install cxr-analyzer "$ROOT/helm/cxr-analyzer" \
  -n "$NS" \
  -f "$HOST_VALUES" \
  --timeout 5m

echo "==> Helm: cxr-ui (ANALYZER_URL -> cxr-analyzer:8766)..."
helm upgrade --install cxr-ui "$ROOT/helm/cxr-ui" \
  -n "$NS" \
  --wait \
  --timeout "$UI_TIMEOUT"

echo ""
kubectl get all,hpa -n "$NS"
helm list -n "$NS"
