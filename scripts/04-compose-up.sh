#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UI_SRC="${CXR_UI_SRC:-$ROOT/../cxr-ui-prune-rehearsal/cxr-ui}"
ANALYZERS="${CXR_ANALYZERS_HOST:-$ROOT/../cxrlabs-dev/claim_analysis_tools}"

export CXR_UI_SRC="$(cd "$UI_SRC" && pwd)"
export CXR_ANALYZERS_HOST="$(cd "$ANALYZERS" && pwd)"
export CXR_OPS_DOCKERFILE="$ROOT/docker/ui/Dockerfile.compose"

if [[ ! -f "$CXR_UI_SRC/package.json" ]]; then
  echo "Missing cxr-ui at $CXR_UI_SRC" >&2
  exit 1
fi
if [[ ! -f "$CXR_ANALYZERS_HOST/analyze_sample.py" ]]; then
  echo "Missing analyze_sample.py under $CXR_ANALYZERS_HOST" >&2
  exit 1
fi

if [[ ! -f "$ROOT/.env.compose.local" ]]; then
  if [[ -f "$CXR_UI_SRC/.env.local" ]]; then
    echo "Creating .env.compose.local from rehearsal .env.local..."
    "$ROOT/scripts/05-sync-compose-env.sh"
  else
    echo "Tip: cp $ROOT/.env.compose.example $ROOT/.env.compose.local and set CXR_SQL_PWD" >&2
  fi
fi

export CXR_STAGING_HOST="${CXR_STAGING_HOST:-$(cd "$ROOT/.." && pwd)}"

cd "$ROOT"
if command -v docker-compose &>/dev/null; then
  DC=(docker-compose)
elif docker compose version &>/dev/null 2>&1; then
  DC=(docker compose)
else
  echo "Need docker-compose or docker compose plugin" >&2
  exit 1
fi

# shellcheck source=compose-files.sh
source "$ROOT/scripts/compose-files.sh"
cxr_compose_files_init
COMPOSE_FILES=("${COMPOSE_FILES[@]}")
if [[ "$COMPOSE_MODE" == host ]]; then
  echo "Linux (native Docker): compose/core/host.yaml → host SQL :1433 + Qdrant :6333"
else
  echo "Bridge overlay ($COMPOSE_MODE): published :3000 + host.docker.internal for SQL/Qdrant/Ollama"
fi

if [[ "${CXR_SKIP_COMPOSE_BUILD:-}" == "1" ]] && docker image inspect cxr-ui:compose &>/dev/null; then
  echo "Skipping image build (CXR_SKIP_COMPOSE_BUILD=1, cxr-ui:compose present)"
else
  echo "Building cxr-ui:compose (UI $CXR_UI_SRC + lab Dockerfile; first ODBC rebuild ~10–20 min)..."
  docker build -f "$ROOT/docker/ui/Dockerfile.compose" -t cxr-ui:compose "$CXR_UI_SRC"
fi
PROFILE_ARGS=()
if [[ "${CXR_COMPOSE_QDRANT:-}" == "1" ]]; then
  PROFILE_ARGS=(--profile with-lab-qdrant)
  echo "Including Qdrant lab sidecar on :6335 (CXR_COMPOSE_QDRANT=1)"
fi
echo "Starting stack (UI http://localhost:3000; host Qdrant :6333 when host overlay)..."
"${DC[@]}" "${COMPOSE_FILES[@]}" "${PROFILE_ARGS[@]}" up -d
"${DC[@]}" "${COMPOSE_FILES[@]}" "${PROFILE_ARGS[@]}" ps
echo ""
echo "Smoke: curl -sI http://localhost:3000/ | head -3"
curl -sI http://localhost:3000/ | head -3 || true
echo ""
echo "Coverage matrix: $ROOT/docs/runbooks/compose-matrix.md"
echo "Claim Studio: analyze + audit/start — host SQL :1433, Qdrant :6333, Ollama :11434"
echo "If 500: ${DC[*]} ${COMPOSE_FILES[*]} logs cxr-ui"
echo "Stop: ${DC[*]} ${COMPOSE_FILES[*]} down"
