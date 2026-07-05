#!/usr/bin/env bash
# Fast PERF-008 analyzer image — layer on existing cxr-analyzer:perf003 (CPU stack).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/bin:${PATH:-}"
ANALYZER_SRC="${CXR_ANALYZER_SRC:-$ROOT/../cxrlabs-dev/claim_analysis_tools}"
BASE_IMAGE="${CXR_ANALYZER_BASE:-cxr-analyzer:perf003}"
IMAGE="${CXR_ANALYZER_IMAGE:-cxr-analyzer:perf008}"

if [[ ! -f "$ANALYZER_SRC/analyzer_metrics.py" ]]; then
  echo "Missing analyzer_metrics.py at $ANALYZER_SRC" >&2
  exit 1
fi

if ! docker image inspect "$BASE_IMAGE" >/dev/null 2>&1; then
  echo "Base image $BASE_IMAGE not found — run 02-build-analyzer-docker-only.sh first (CPU build)." >&2
  exit 1
fi

echo "Layer build $IMAGE from $BASE_IMAGE (prometheus-client + analyzer_metrics only)..."
docker build -t "$IMAGE" \
  --build-arg "BASE=$BASE_IMAGE" \
  -f "$ROOT/Dockerfile.analyzer.perf008-layer" \
  "$ANALYZER_SRC"
echo "Built $IMAGE (CPU image — same as perf003 base, no GPU in container)"
