#!/usr/bin/env bash
# Build cxr-analyzer:local and load into kind (warm FastAPI :8766).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/bin:${PATH:-}"
# shellcheck source=lib/kind-common.sh
source "$ROOT/scripts/lib/kind-common.sh"
CLUSTER="${CXR_KIND_CLUSTER:-cxr-lab}"
ANALYZER_SRC="${CXR_ANALYZER_SRC:-$ROOT/../cxrlabs-dev/claim_analysis_tools}"
IMAGE="${CXR_ANALYZER_IMAGE:-cxr-analyzer:local}"

if [[ ! -f "$ANALYZER_SRC/analyzer_service_app.py" ]]; then
  echo "Missing analyzer at $ANALYZER_SRC" >&2
  exit 1
fi

cp "$ROOT/requirements-analyzer-docker.txt" "$ANALYZER_SRC/requirements-analyzer-docker.txt"

"$ROOT/scripts/02-build-analyzer-docker-only.sh"
load_image_to_cluster "$IMAGE" "$ROOT"
echo "Image $IMAGE ready for cluster ($(cxr_k8_runtime))"
