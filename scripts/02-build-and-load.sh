#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/bin:${PATH:-}"
# shellcheck source=lib/kind-common.sh
source "$ROOT/scripts/lib/kind-common.sh"
CLUSTER="${CXR_KIND_CLUSTER:-cxr-lab}"
UI_SRC="${CXR_UI_SRC:-$ROOT/../cxr-ui-prune-rehearsal/cxr-ui}"
IMAGE="${CXR_UI_IMAGE:-cxr-ui:local}"

if [[ ! -f "$UI_SRC/package.json" ]]; then
  echo "Missing cxr-ui at $UI_SRC" >&2
  exit 1
fi

echo "Building $IMAGE from $UI_SRC (this may take several minutes)..."
docker build -t "$IMAGE" -f "$ROOT/Dockerfile" "$UI_SRC"
load_image_to_cluster "$IMAGE" "$ROOT"
echo "Image $IMAGE ready for cluster ($(cxr_k8_runtime))"
