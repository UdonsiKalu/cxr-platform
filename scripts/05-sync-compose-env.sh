#!/usr/bin/env bash
# Create .env.compose.local from rehearsal .env.local (secrets stay local, gitignored).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${CXR_ENV_SRC:-$ROOT/../cxr-ui-prune-rehearsal/cxr-ui/.env.local}"
OUT="$ROOT/.env.compose.local"

if [[ ! -f "$SRC" ]]; then
  echo "Missing $SRC — copy .env.compose.example to .env.compose.local and edit." >&2
  exit 1
fi

{
  echo "# Generated from $SRC — $(date -Iseconds)"
  echo "# Host-network compose (:3000 lab)"
  grep -E '^(CXR_SQL_|CXR_TERMINAL_|CXR_ARCHETYPE_|CXR_DATA_|CXR_ADMIN_|QDRANT_)' "$SRC" || true
  cat <<'EOF'

CXR_JUDGE_BACKEND=ollama
CXR_JUDGE_MODEL=llama3:8b-instruct-q4_0
OLLAMA_HOST=http://127.0.0.1:11434
CXR_GATEWAY_URL=http://127.0.0.1:8181
CXR_API_BASE=http://127.0.0.1:8281
EOF
} >"$OUT"

chmod 600 "$OUT"
echo "Wrote $OUT"
echo "Review CXR_SQL_SERVER (should be 127.0.0.1,1433 for compose.host.yaml)."
