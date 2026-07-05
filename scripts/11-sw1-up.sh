#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UI_SRC="${CXR_UI_SRC:-$ROOT/../cxr-ui-prune-rehearsal/cxr-ui}"
IMAGE="${CXR_UI_IMAGE:-cxr-ui:local}"
NAME="${CXR_SW1_CONTAINER:-cxr-sw1-test}"
PORT="${CXR_SW1_PORT:-3002}"

if [[ ! -f "$UI_SRC/package.json" ]]; then
  echo "Missing cxr-ui at $UI_SRC" >&2
  exit 1
fi

until docker info &>/dev/null; do
  echo "Waiting for Docker..."
  sleep 2
done

if ! docker image inspect "$IMAGE" &>/dev/null; then
  echo "Building $IMAGE (first run may take several minutes)..."
  docker build -t "$IMAGE" -f "$ROOT/docker/ui/Dockerfile" "$UI_SRC"
fi

if docker ps -a --format '{{.Names}}' | grep -qx "$NAME"; then
  docker start "$NAME" >/dev/null
  echo "Started existing container $NAME on :$PORT"
else
  docker run -d -p "${PORT}:3000" --name "$NAME" --restart unless-stopped "$IMAGE"
  echo "Created $NAME on :$PORT ($IMAGE)"
fi
