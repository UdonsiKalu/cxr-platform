#!/usr/bin/env bash
# Background CSV collector for K8 + Locust load tests (LOAD-003 / SRE investigation).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/bin:${PATH:-}"

OUT="${1:-${CXR_LOAD_METRICS_CSV:-/tmp/cxr-k8-load-metrics.csv}}"
INTERVAL="${CXR_LOAD_METRICS_INTERVAL:-5}"
NS="${CXR_K8_NAMESPACE:-cxr-ui}"
LOCUST_URL="${CXR_LOCUST_URL:-http://127.0.0.1:8090}"

exec python3 "$ROOT/scripts/collect_load_metrics.py" \
  --output "$OUT" \
  --interval "$INTERVAL" \
  --namespace "$NS" \
  --locust-url "$LOCUST_URL"
