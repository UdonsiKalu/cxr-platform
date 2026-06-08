#!/usr/bin/env bash
# Load lab — k6 CLI (install k6 separately; see load/README.md).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export CXR_LOAD_URL="${CXR_LOAD_URL:-http://127.0.0.1:3000}"
export K6_VUS="${K6_VUS:-3}"
export K6_DURATION="${K6_DURATION:-2m}"

if ! command -v k6 &>/dev/null; then
  echo "k6 not found on PATH." >&2
  echo "  Install: https://grafana.com/docs/k6/latest/set-up/install-k6/" >&2
  echo "  Or use Locust UI: ./scripts/22-load-locust.sh" >&2
  exit 1
fi

if ! curl -sf -o /dev/null --connect-timeout 2 "${CXR_LOAD_URL}/claim-studio" 2>/dev/null; then
  echo "WARN CXR not reachable at ${CXR_LOAD_URL}/claim-studio" >&2
fi

echo "== CXR k6 load =="
echo "  CXR_LOAD_URL=${CXR_LOAD_URL}  K6_VUS=${K6_VUS}  K6_DURATION=${K6_DURATION}"
echo ""

exec k6 run "$ROOT/load/k6/claim-studio-analyze.js"
