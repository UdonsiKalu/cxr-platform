#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/bin:${PATH:-}"
CLUSTER="${CXR_KIND_CLUSTER:-cxr-lab}"
KIND_CONFIG="$ROOT/kind/cxr-lab.yaml"

host_gateway_ip() {
  if [[ -n "${CXR_HOST_IP:-}" ]]; then
    echo "$CXR_HOST_IP"
    return
  fi
  ip -4 route show default 2>/dev/null | awk '{print $3}' | head -1
}

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  echo "kind cluster '$CLUSTER' already exists"
  HOST_IP="$(host_gateway_ip)"
  echo "Host gateway for pods (SQL/Qdrant): ${HOST_IP:-unknown} — override with CXR_HOST_IP"
else
  HOST_IP="$(host_gateway_ip)"
  if [[ -z "$HOST_IP" ]]; then
    HOST_IP="172.17.0.1"
  fi
  echo "Creating kind cluster '$CLUSTER' (pods use host gateway IP $HOST_IP for SQL/Qdrant)"
  echo "$HOST_IP" > /tmp/cxr-kind-host-ip
  kind create cluster --config "$KIND_CONFIG"
fi

kubectl cluster-info --context "kind-${CLUSTER}"
