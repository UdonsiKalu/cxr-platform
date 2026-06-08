#!/usr/bin/env bash
# SW.18 — Langfuse health + optional trace ingest.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if curl -sf -o /dev/null -w "" "http://localhost:3100/"; then
  echo "OK  Langfuse :3100"
else
  echo "FAIL Langfuse :3100" >&2
  exit 1
fi

if [[ -f "$ROOT/lab/langfuse/keys.env" ]]; then
  if command -v node &>/dev/null; then
    (cd "$ROOT/lab/langfuse" && npm install --omit=dev --silent 2>/dev/null || true)
    node "$ROOT/lab/langfuse/send-trace.mjs"
  else
    echo "SKIP  node not on host — install keys.env and run send-trace.mjs later"
  fi
else
  echo "SKIP  trace ingest — copy lab/langfuse/keys.env.example → keys.env after UI signup"
fi

echo ""
echo "Browser: http://localhost:3100 → Traces → cxr-sw18-golden-path"
