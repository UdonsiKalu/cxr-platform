#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/bin:${PATH:-}"
CLUSTER="${CXR_KIND_CLUSTER:-cxr-lab}"

until docker info &>/dev/null; do
  echo "Waiting for Docker..."
  sleep 2
done

if ! docker inspect "cxr-lab-control-plane" &>/dev/null; then
  echo "Creating kind cluster $CLUSTER..."
  "$ROOT/scripts/01-kind-cluster.sh"
elif ! docker inspect -f '{{.State.Running}}' cxr-lab-control-plane 2>/dev/null | grep -qx true; then
  echo "Starting kind node cxr-lab-control-plane..."
  docker start cxr-lab-control-plane
  for _ in $(seq 1 60); do
    kubectl cluster-info --context "kind-${CLUSTER}" &>/dev/null && break
    sleep 2
  done
fi

if ! docker image inspect cxr-ui:local &>/dev/null; then
  echo "Building cxr-ui:local for kind..."
  "$ROOT/scripts/02-build-and-load.sh"
else
  echo "Loading cxr-ui:local into kind (idempotent)..."
  kind load docker-image cxr-ui:local --name "$CLUSTER"
fi

echo "Helm upgrade --install (idempotent)..."
"$ROOT/scripts/05-helm-install.sh"

# Free :8081 if a stale manual port-forward is still bound
if command -v fuser &>/dev/null; then
  fuser -k 8081/tcp 2>/dev/null || true
  sleep 1
fi
