#!/usr/bin/env bash
# PERF-009 — Jaeger tail latency attribution replay (PERF-008 helm profiles A/B).
# Does NOT change autoscaling policy; captures fast vs slow POST traces @ ~200 users.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/bin:${PATH:-}"
NS="${CXR_K8_NAMESPACE:-cxr-ui}"
EXP="${1:-}"

if [[ "$EXP" != "a" && "$EXP" != "b" ]]; then
  cat <<EOF
Usage: $0 {a|b}

  Attribution replay for PERF-008 experiment A or B:
    - Helm overlay values-perf008-exp-{a|b}.yaml (KEDA mode unchanged)
    - Abbreviated cumulative ramp 25→200 (45s/tier, 4m @200 soak)
    - Jaeger extract: 3 fast (~100–200ms) + 3 slow (~700–900ms) POST traces

Prereq: ./scripts/23-k8-load-observe-up.sh, Jaeger :16686, UI :8081

EOF
  exit 1
fi

OVERLAY="$ROOT/helm/cxr-analyzer/values-perf008-exp-${EXP}.yaml"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$ROOT/evidence/perf009/exp-${EXP}-${STAMP}"
mkdir -p "$OUT"

echo "==> PERF-009 Jaeger attribution — experiment ${EXP} @ ${STAMP}"

echo "==> Helm upgrade (PERF-008 overlay, no image rebuild)"
helm upgrade cxr-analyzer "$ROOT/helm/cxr-analyzer" -n "$NS" \
  -f "$ROOT/helm/cxr-analyzer/values.yaml" \
  -f "$OVERLAY" \
  --set image.tag=perf008 \
  --wait --timeout 15m

kubectl rollout restart deployment/cxr-analyzer -n "$NS"
kubectl rollout status deployment/cxr-analyzer -n "$NS" --timeout=600s

"$ROOT/scripts/23-k8-load-observe-up.sh"

START_US="$(python3 -c 'import time; print(int(time.time()*1e6))')"
echo "$START_US" > "$OUT/window-start-us.txt"

export CXR_GATE_MODE=cumulative
export CXR_GATE_RAMP_START=25
export CXR_GATE_RAMP_STEP=25
export CXR_GATE_RAMP_MAX=200
export CXR_GATE_STAGE_TIME=45s
export CXR_GATE_RAMP_HOLD=4m
export CXR_GATE_SPAWN_RATE=2
export CXR_RAMP_PROFILE=analyzer_saturation
export CXR_GATE_SCORE_CHECKPOINTS="100 150 200"
export CXR_GATE_OUTPUT_DIR="$OUT"
export CXR_LOAD_URL="${CXR_LOAD_URL:-http://127.0.0.1:8081}"
export CXR_LOCUST_URL="${CXR_LOCUST_URL:-http://127.0.0.1:8092}"

echo "==> Load window start_us=$START_US"
"$ROOT/scripts/k8-load-gate.sh" --cumulative --skip-preflight | tee "$OUT/gate-console.log" || true

END_US="$(python3 -c 'import time; print(int(time.time()*1e6))')"
echo "$END_US" > "$OUT/window-end-us.txt"

EXP_LABEL="$(echo "$EXP" | tr '[:lower:]' '[:upper:]')"
python3 "$ROOT/scripts/lib/perf009_jaeger_extract.py" \
  --experiment "$EXP_LABEL" \
  --stamp "$STAMP" \
  --start-us "$START_US" \
  --end-us "$END_US" \
  --out "$OUT/jaeger-attribution.json"

echo "==> Evidence: $OUT"
echo "    Jaeger search: http://127.0.0.1:16686/search?service=cxr-ui-k8&operation=POST"
