#!/usr/bin/env bash
# LOAD-004 — delete single-node kind cluster and recreate with 2 worker nodes.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/bin:${PATH:-}"
CLUSTER="${CXR_KIND_CLUSTER:-cxr-lab}"
CONFIG="$ROOT/kind/cxr-lab-expanded.yaml"

resolve_pod_host_ip() {
  if [[ -n "${CXR_HOST_IP:-}" ]]; then
    echo "$CXR_HOST_IP"
    return
  fi
  if docker inspect cxr-lab-control-plane &>/dev/null 2>&1; then
    if docker exec cxr-lab-control-plane getent hosts host.docker.internal &>/dev/null; then
      echo "host.docker.internal"
      return
    fi
  fi
  local gw
  gw="$(ip -4 route show default 2>/dev/null | awk '{print $3; exit}' || true)"
  if [[ -n "$gw" ]]; then
    echo "$gw"
    return
  fi
  echo "172.17.0.1"
}

HOST_IP="$(resolve_pod_host_ip)"
echo "Host gateway for analyzer pods (SQL/Qdrant): $HOST_IP"
echo "$HOST_IP" > /tmp/cxr-kind-host-ip

if kind get clusters 2>/dev/null | grep -qx "$CLUSTER"; then
  echo "Deleting kind cluster '$CLUSTER'..."
  if ! kind delete cluster --name "$CLUSTER"; then
    echo "kind delete failed — removing orphaned cxr-lab containers..."
    docker rm -f "cxr-lab-control-plane" "cxr-lab-worker" "cxr-lab-worker2" 2>/dev/null || true
  fi
fi
# Orphan containers (e.g. partial create after failed delete) block kind create.
for c in cxr-lab-control-plane cxr-lab-worker cxr-lab-worker2; do
  if docker ps -a --format '{{.Names}}' | grep -qx "$c"; then
    echo "Removing stale container $c..."
    docker rm -f "$c"
  fi
done

echo "Creating expanded kind cluster '$CLUSTER' (1 control-plane + 2 workers)..."
if ! kind create cluster --config "$CONFIG"; then
  echo "kind create failed — removing partial cxr-lab containers..."
  docker rm -f "cxr-lab-control-plane" "cxr-lab-worker" "cxr-lab-worker2" 2>/dev/null || true
  exit 1
fi

kubectl cluster-info --context "kind-${CLUSTER}"
kubectl get nodes -o wide

# Re-resolve after workers exist (pre-delete gw IP e.g. 192.168.4.1 often fails SQL from workers).
if docker exec cxr-lab-worker bash -c 'timeout 2 bash -c "</dev/tcp/host.docker.internal/1433"' 2>/dev/null; then
  HOST_IP="host.docker.internal"
  echo "$HOST_IP" > /tmp/cxr-kind-host-ip
  echo "Host gateway for analyzer pods (SQL/Qdrant): $HOST_IP (verified from worker)"
fi

echo ""
echo "Expanded cluster ready. Next:"
echo "  CXR_HOST_IP=${HOST_IP} CXR_SKIP_ANALYZER_BUILD=1 $ROOT/scripts/04-kind-load-images-only.sh"
echo "  CXR_HOST_IP=${HOST_IP} $ROOT/scripts/06-helm-install-stack.sh"
echo "  $ROOT/scripts/16-k8-stack-verify.sh"
