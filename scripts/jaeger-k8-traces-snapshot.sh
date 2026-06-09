#!/usr/bin/env bash
# Export recent Jaeger traces from cxr-analyzer-service (K8 load test evidence).
set -euo pipefail
JAEGER="${CXR_JAEGER_URL:-http://127.0.0.1:16686}"
SERVICE="${CXR_JAEGER_SERVICE:-cxr-analyzer-service}"
LIMIT="${CXR_JAEGER_LIMIT:-20}"
OUT="${1:-/tmp/cxr-jaeger-k8-traces.json}"

URL="${JAEGER}/api/traces?service=${SERVICE}&limit=${LIMIT}"
echo "Fetching ${URL} ..."
if ! curl -sf "$URL" -o "$OUT"; then
  echo "Failed — is Jaeger up? (./scripts/07-observe-up.sh or ./scripts/23-k8-load-observe-up.sh)" >&2
  exit 1
fi
COUNT="$(python3 -c "import json; d=json.load(open('$OUT')); print(len(d.get('data',[])))")"
echo "Wrote ${OUT} (${COUNT} traces)"
echo "Jaeger UI: ${JAEGER}/search?service=${SERVICE}"
