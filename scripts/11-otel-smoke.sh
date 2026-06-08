#!/usr/bin/env bash
# SW.11 — smoke: observe stack up, probe Jaeger, optional curl to CXR analyze API.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

JAEGER_UI="${CXR_JAEGER_UI:-http://127.0.0.1:16686}"
COLLECTOR="${CXR_OTEL_HTTP:-http://127.0.0.1:4318}"
CXR_URL="${CXR_SMOKE_URL:-http://127.0.0.1:8251}"

echo "== SW.11 OTel smoke =="

if ! curl -sf "${JAEGER_UI}/" >/dev/null; then
  echo "Jaeger UI not reachable at ${JAEGER_UI} — run ./scripts/07-observe-up.sh" >&2
  exit 1
fi
echo "OK Jaeger UI ${JAEGER_UI}"

if command -v docker &>/dev/null; then
  if docker ps --format '{{.Names}}' | grep -q otel-collector; then
    echo "OK otel-collector container running"
  else
    echo "WARN no otel-collector container (observe stack down?)" >&2
  fi
fi

if curl -sf -o /dev/null -w '' "${CXR_URL}/claim-studio" 2>/dev/null; then
  echo "CXR UI up at ${CXR_URL} — generate a trace: open Claim Studio, Run Analysis"
  echo "Or: POST ${CXR_URL}/api/claim-studio/analyze (with OTEL env on the Next server)"
else
  echo "CXR not on ${CXR_URL} — start with OTEL env:"
  echo "  source <(grep -v '^#' ${ROOT}/.env.otel.example | grep -v '^$' | sed 's/^/export /')"
  echo "  cd ../cxr-ui-prune-rehearsal/cxr-ui && npm run dev:rehearsal"
fi

echo ""
echo "Then open Jaeger → Search → Service = cxr-ui-rehearsal or cxr-ui-compose"
echo "Evidence: screenshot + ${ROOT}/evidence/SW11-otel-verify-*.md"
