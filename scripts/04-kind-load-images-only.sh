#!/usr/bin/env bash
# Load cxr-ui:local + cxr-analyzer:local into kind (no docker build).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/bin:${PATH:-}"
# shellcheck source=lib/kind-common.sh
source "$ROOT/scripts/lib/kind-common.sh"
CLUSTER="${CXR_KIND_CLUSTER:-cxr-lab}"
UI_IMAGE="${CXR_UI_IMAGE:-cxr-ui:local}"
AN_IMAGE="${CXR_ANALYZER_IMAGE:-cxr-analyzer:local}"

ensure_kind_cluster "$ROOT"
require_kubectl "$ROOT"

for img in "$UI_IMAGE" "$AN_IMAGE"; do
  if ! docker image inspect "$img" &>/dev/null; then
    echo "ERROR: missing Docker image $img — run 02-build-and-load.sh / 02-build-analyzer-and-load.sh first" >&2
    exit 1
  fi
  echo "Loading $img into kind cluster $CLUSTER..."
  kind load docker-image "$img" --name "$CLUSTER"
done

echo "Both images loaded into kind cluster $CLUSTER"
