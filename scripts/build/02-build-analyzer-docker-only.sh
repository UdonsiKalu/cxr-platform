#!/usr/bin/env bash
# Build cxr-analyzer:local only (no kind load — use with Docker Desktop K8).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export PATH="$ROOT/bin:${PATH:-}"
ANALYZER_SRC="${CXR_ANALYZER_SRC:-$ROOT/../cxrlabs-dev/claim_analysis_tools}"
IMAGE="${CXR_ANALYZER_IMAGE:-cxr-analyzer:local}"

if [[ ! -f "$ANALYZER_SRC/analyzer_service_app.py" ]]; then
  echo "Missing analyzer at $ANALYZER_SRC" >&2
  exit 1
fi

cp "$ROOT/docker/analyzer/requirements.txt" "$ANALYZER_SRC/requirements-analyzer-docker.txt"

echo "Building $IMAGE (CPU torch/faiss — may take 15–30 min on first build)..."
docker build -t "$IMAGE" -f "$ROOT/docker/analyzer/Dockerfile" "$ANALYZER_SRC"
echo "Built $IMAGE"
