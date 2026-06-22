#!/usr/bin/env bash
# PERF-008 — controlled A/B load run (does NOT modify k8-load-gate.sh or k8-load-tuner.sh).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/bin:${PATH:-}"
NS="${CXR_K8_NAMESPACE:-cxr-ui}"
EXP="${1:-}"

if [[ "$EXP" != "a" && "$EXP" != "b" ]]; then
  cat <<EOF
Usage: $0 {a|b}

  a — Experiment A: KEDA E2E Locust p95 + CPU (values-perf008-exp-a.yaml)
  b — Experiment B: in-flight/backpressure per pod + CPU (values-perf008-exp-b.yaml)

Prerequisites:
  1. Rebuilt analyzer image cxr-analyzer:perf008 with /metrics
  2. ./scripts/23-k8-load-observe-up.sh

EOF
  exit 1
fi

OVERLAY="$ROOT/helm/cxr-analyzer/values-perf008-exp-${EXP}.yaml"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$ROOT/evidence/perf008/exp-${EXP}-${STAMP}"
mkdir -p "$OUT"

echo "==> PERF-008 experiment ${EXP} @ ${STAMP}"

FAISS_VENV="${CXR_FAISS_VENV:-/home/udonsi-kalu/staging/cxrlabs/faiss_gpu1}"
if [[ -x "$FAISS_VENV/bin/pip" ]]; then
  echo "==> faiss_gpu1: prometheus-client (deps already in venv for local analyzer)"
  "$FAISS_VENV/bin/pip" install -q 'prometheus-client>=0.20.0'
else
  echo "WARN: faiss_gpu1 not at $FAISS_VENV — set CXR_FAISS_VENV" >&2
fi

echo "==> Layer analyzer image (CPU cxr-analyzer:perf003 base → tag perf008)"
"$ROOT/scripts/02-build-analyzer-perf008-layer.sh"

echo "==> Helm upgrade (KEDA trigger overlay + perf008 image tag)"
helm upgrade cxr-analyzer "$ROOT/helm/cxr-analyzer" -n "$NS" \
  -f "$ROOT/helm/cxr-analyzer/values.yaml" \
  -f "$OVERLAY" \
  --set image.tag=perf008 \
  --wait --timeout 15m

echo "==> Rollout restart analyzer (perf008 tag)"
kubectl rollout restart deployment/cxr-analyzer -n "$NS"
kubectl rollout status deployment/cxr-analyzer -n "$NS" --timeout=600s

echo "==> Observe stack"
"$ROOT/scripts/23-k8-load-observe-up.sh"

echo "==> Verify analyzer /metrics"
sleep 3
curl -sf "http://127.0.0.1:8767/metrics" | grep -E '^cxr_analyzer_inflight' | head -3 || {
  echo "WARN: analyzer metrics scrape not ready — check k8-analyzer-metrics-forward.sh" >&2
}

echo "==> Cumulative load (GATE-002 comparable profile — gate script unchanged)"
export CXR_GATE_MODE=cumulative
export CXR_GATE_RAMP_START=15
export CXR_GATE_RAMP_STEP=5
export CXR_GATE_RAMP_MAX=200
export CXR_GATE_STAGE_TIME=60s
export CXR_GATE_RAMP_HOLD=3m
export CXR_GATE_SPAWN_RATE=2
export CXR_RAMP_PROFILE=analyzer_saturation
export CXR_GATE_SCORE_CHECKPOINTS="50 100 150 200"
export CXR_GATE_OUTPUT_DIR="$OUT"
export CXR_LOAD_URL="${CXR_LOAD_URL:-http://127.0.0.1:8081}"
export CXR_LOCUST_URL="${CXR_LOCUST_URL:-http://127.0.0.1:8092}"

"$ROOT/scripts/k8-load-gate.sh" --cumulative --skip-preflight | tee "$OUT/gate-console.log" || true

GATE_CSV="$(ls -t "$OUT"/gate-*-cumulative.csv 2>/dev/null | head -1 || true)"
if [[ -n "$GATE_CSV" ]]; then
  python3 "$ROOT/scripts/lib/perf008_summarize_run.py" --experiment "$EXP" --dir "$OUT" \
    > "$OUT/summary.json" 2>"$OUT/summary.log" || true
fi

echo ""
echo "Results: $OUT"
echo "Grafana: http://127.0.0.1:3001/d/cxr-hpa-load-003 — export screenshots into $OUT"
