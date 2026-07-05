#!/usr/bin/env bash
# GATE-001 — Performance regression gate for K8 LOAD-003.
# Discrete stages OR one cumulative ramp (25→200 by default).
#
# Prereq: stack verify, observe up (23-k8-load-observe-up.sh), UI :8081.
#
# Usage:
#   export PATH="$HOME/staging/cxr-ops-lab/bin:$PATH"
#   ./scripts/k8-load-gate.sh
#   CXR_GATE_MODE=cumulative ./scripts/k8-load-gate.sh
#   CXR_GATE_STAGES="50 100" CXR_GATE_STAGE_TIME=2m ./scripts/k8-load-gate.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/bin:${PATH:-}"
# shellcheck source=lib/kind-common.sh
source "$ROOT/scripts/lib/kind-common.sh"

NS="${CXR_K8_NAMESPACE:-cxr-ui}"
HOST="${CXR_LOAD_URL:-http://127.0.0.1:8081}"
LOCUST_URL="${CXR_LOCUST_URL:-http://127.0.0.1:8092}"
GATE_MODE="${CXR_GATE_MODE:-discrete}"
STAGES="${CXR_GATE_STAGES:-50 100 150 200}"
STAGE_TIME="${CXR_GATE_STAGE_TIME:-3m}"
SPAWN_RATE="${CXR_GATE_SPAWN_RATE:-5}"
RAMP_START="${CXR_GATE_RAMP_START:-25}"
RAMP_STEP="${CXR_GATE_RAMP_STEP:-25}"
RAMP_MAX="${CXR_GATE_RAMP_MAX:-200}"
RAMP_HOLD="${CXR_GATE_RAMP_HOLD:-2m}"
RAMP_PROFILE="${CXR_RAMP_PROFILE:-lightweight_mixed}"
SCORE_CHECKPOINTS="${CXR_GATE_SCORE_CHECKPOINTS:-}"
INTERVAL="${CXR_LOAD_METRICS_INTERVAL:-5}"
SOFT_200=0
SKIP_PREFLIGHT=0

usage() {
  cat <<EOF
Usage: $0 [--soft-200] [--skip-preflight] [--cumulative]

  CXR_GATE_MODE              discrete (default) or cumulative
  CXR_GATE_STAGES            Discrete only: space-separated user counts
  CXR_GATE_STAGE_TIME        Discrete: per-stage duration; cumulative: seconds per tier
  CXR_GATE_RAMP_START        Cumulative first tier (default 25)
  CXR_GATE_RAMP_STEP         Cumulative step (default 25)
  CXR_GATE_RAMP_MAX          Cumulative ceiling (default 200)
  CXR_GATE_RAMP_HOLD         Extra soak at max after ramp (default 2m)

Exit 0 = all strict stages/checkpoints passed. Exit 1 = any failed.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --soft-200) SOFT_200=1 ;;
    --skip-preflight) SKIP_PREFLIGHT=1 ;;
    --cumulative) GATE_MODE=cumulative ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

MAX_COLLAPSES="${CXR_GATE_MAX_COLLAPSES:-0}"
MAX_FAILURES="${CXR_GATE_MAX_FAILURES:-0.5}"
OUT_DIR="${CXR_GATE_OUTPUT_DIR:-/tmp/cxr-load-gate}"
mkdir -p "$OUT_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
REPORT="$OUT_DIR/gate-report-${STAMP}.json"
SUMMARY="$OUT_DIR/gate-report-${STAMP}.txt"
STAGE_JSON_DIR="$OUT_DIR/gate-${STAMP}-stages"
mkdir -p "$STAGE_JSON_DIR"

LOCUST_VENV="$ROOT/load/locust/.venv"
SCORER="$ROOT/scripts/lib/load_gate_score.py"
LOCUST_DIR="$ROOT/load/locust"

duration_seconds() {
  python3 - <<PY
t = "${1}"
if t.endswith("m"):
    print(int(t[:-1]) * 60)
elif t.endswith("s"):
    print(int(t[:-1]))
else:
    print(int(t))
PY
}

score_checkpoints_list() {
  if [[ -n "$SCORE_CHECKPOINTS" ]]; then
    echo "$SCORE_CHECKPOINTS"
    return
  fi
  ramp_checkpoints
}

ramp_checkpoints() {
  python3 - <<PY
start, step, mx = int("$RAMP_START"), int("$RAMP_STEP"), int("$RAMP_MAX")
users = []
u = start
while u <= mx:
    users.append(u)
    u += step
print(" ".join(str(x) for x in users))
PY
}

ramp_run_seconds() {
  python3 - <<PY
start, step, mx = int("$RAMP_START"), int("$RAMP_STEP"), int("$RAMP_MAX")
tier_s = int("$(duration_seconds "$STAGE_TIME")")
hold_s = int("$(duration_seconds "$RAMP_HOLD")")
n = 1 if start > mx else (mx - start) // step + 1
print(n * tier_s + hold_s)
PY
}

ensure_locust() {
  if [[ ! -x "$LOCUST_VENV/bin/locust" ]]; then
    python3 -m venv "$LOCUST_VENV"
    "$LOCUST_VENV/bin/pip" install -q --upgrade pip
    "$LOCUST_VENV/bin/pip" install -q -r "$ROOT/load/locust/requirements.txt"
  fi
}

preflight() {
  echo "== GATE-001 preflight =="
  if [[ "$SKIP_PREFLIGHT" -eq 0 ]]; then
    "$ROOT/scripts/16-k8-stack-verify.sh"
  fi
  if ! "$ROOT/scripts/k8-load-exporter.sh" check; then
    echo "Starting load exporter..."
    "$ROOT/scripts/k8-load-exporter.sh" start
  fi
  if [[ "$GATE_MODE" == "cumulative" ]]; then
    echo "  mode=cumulative  profile=${RAMP_PROFILE}  ramp=${RAMP_START}+${RAMP_STEP}→${RAMP_MAX}  tier=${STAGE_TIME}  hold=${RAMP_HOLD}"
  else
    echo "  mode=discrete  stages=$STAGES  stage_time=$STAGE_TIME"
  fi
  echo "  namespace=$NS  host=$HOST"
  echo ""
}

clear_locust_port() {
  local locust_port="$1"
  pkill -f "locust.*--web-port ${locust_port}" 2>/dev/null || true
  if command -v fuser &>/dev/null; then
    fuser -k "${locust_port}/tcp" 2>/dev/null || true
  fi
  sleep 1
}

run_stage() {
  local users="$1"
  local soft="$2"
  local csv="$OUT_DIR/gate-${STAMP}-u${users}.csv"
  local json_out="$STAGE_JSON_DIR/u${users}.json"
  local collector_pid=""
  local stage_rc=0
  local locust_port="${LOCUST_URL##*:}"
  locust_port="${locust_port%%/*}"

  echo "== Stage: ${users} users (${STAGE_TIME}) =="
  rm -f "$csv"
  export CXR_LOCUST_URL="$LOCUST_URL"

  clear_locust_port "$locust_port"

  python3 "$ROOT/scripts/collect_load_metrics.py" \
    --output "$csv" \
    --interval "$INTERVAL" \
    --namespace "$NS" \
    --locust-url "$LOCUST_URL" &
  collector_pid=$!
  sleep 2

  echo "  Locust web :${locust_port} autostart ${users} users for ${STAGE_TIME}"
  CXR_LOAD_URL="$HOST" CXR_LOCUST_USERS="$users" CXR_LOCUST_SPAWN="$SPAWN_RATE" \
    CXR_LOCUST_TIME="$STAGE_TIME" CXR_LOCUST_WEB_PORT="$locust_port" \
    "$ROOT/scripts/22-load-locust.sh" --autostart || true

  kill "$collector_pid" 2>/dev/null || true
  wait "$collector_pid" 2>/dev/null || true
  sleep 1

  local scorer_args=(--users "$users" --max-collapses "$MAX_COLLAPSES" --max-failures-per-s "$MAX_FAILURES" --json)
  if [[ "$soft" -eq 1 ]]; then
    scorer_args+=(--soft)
  fi
  python3 "$SCORER" "$csv" "${scorer_args[@]}" >"$json_out"

  if ! python3 "$SCORER" "$csv" --users "$users" --max-collapses "$MAX_COLLAPSES" \
    --max-failures-per-s "$MAX_FAILURES" $([[ "$soft" -eq 1 ]] && echo --soft); then
    stage_rc=1
  fi
  return "$stage_rc"
}

score_checkpoint() {
  local csv="$1"
  local users="$2"
  local soft="$3"
  local json_out="$STAGE_JSON_DIR/u${users}.json"
  local max_tier=0
  [[ "$users" -eq "$RAMP_MAX" ]] && max_tier=1

  local scorer_args=(
    --users "$users"
    --max-collapses "$MAX_COLLAPSES"
    --max-failures-per-s "$MAX_FAILURES"
    --ramp-step "$RAMP_STEP"
    --json
  )
  [[ "$max_tier" -eq 1 ]] && scorer_args+=(--max-tier)
  [[ "$soft" -eq 1 ]] && scorer_args+=(--soft)

  python3 "$SCORER" "$csv" "${scorer_args[@]}" >"$json_out"
  python3 "$SCORER" "$csv" --users "$users" --max-collapses "$MAX_COLLAPSES" \
    --max-failures-per-s "$MAX_FAILURES" --ramp-step "$RAMP_STEP" \
    $([[ "$max_tier" -eq 1 ]] && echo --max-tier) \
    $([[ "$soft" -eq 1 ]] && echo --soft)
}

run_cumulative_ramp() {
  local csv="$OUT_DIR/gate-${STAMP}-cumulative.csv"
  local collector_pid=""
  local failed=0
  local locust_port="${LOCUST_URL##*:}"
  locust_port="${locust_port%%/*}"
  local tier_s hold_s run_s run_time

  tier_s="$(duration_seconds "$STAGE_TIME")"
  hold_s="$(duration_seconds "$RAMP_HOLD")"
  export CXR_RAMP_START_USERS="$RAMP_START"
  export CXR_RAMP_STEP_USERS="$RAMP_STEP"
  export CXR_RAMP_MAX_USERS="$RAMP_MAX"
  export CXR_RAMP_STAGE_SECONDS="$tier_s"
  export CXR_RAMP_HOLD_AT_MAX_S="$hold_s"
  export CXR_CAPACITY_SPAWN_RATE="$SPAWN_RATE"
  export CXR_RAMP_PROFILE="$RAMP_PROFILE"
  run_s="$(ramp_run_seconds)"
  run_time="${run_s}s"

  echo "== Cumulative ramp [${RAMP_PROFILE}]: ${RAMP_START} +${RAMP_STEP} → ${RAMP_MAX} (${tier_s}s/tier, ${hold_s}s@max, ~${run_s}s total) =="
  rm -f "$csv"
  export CXR_LOCUST_URL="$LOCUST_URL"
  clear_locust_port "$locust_port"

  python3 "$ROOT/scripts/collect_load_metrics.py" \
    --output "$csv" \
    --interval "$INTERVAL" \
    --namespace "$NS" \
    --locust-url "$LOCUST_URL" &
  collector_pid=$!
  sleep 2

    CXR_LOAD_URL="$HOST" CXR_LOCUST_TIME="$run_time" CXR_LOCUST_WEB_PORT="$locust_port" \
    CXR_RAMP_PROFILE="$RAMP_PROFILE" \
    "$ROOT/scripts/22-load-locust.sh" --ramp-autostart || true

  kill "$collector_pid" 2>/dev/null || true
  wait "$collector_pid" 2>/dev/null || true
  sleep 1

  local users soft=0
  for users in $(score_checkpoints_list); do
    soft=0
    if [[ "$users" == "$RAMP_MAX" && "$SOFT_200" -eq 1 ]]; then
      soft=1
    fi
    echo "  Checkpoint @${users} users"
    if ! score_checkpoint "$csv" "$users" "$soft"; then
      failed=1
    fi
  done
  return "$failed"
}

main() {
  ensure_locust
  preflight

  local failed=0
  if [[ "$GATE_MODE" == "cumulative" ]]; then
    if ! run_cumulative_ramp; then
      failed=1
    fi
  else
    for users in $STAGES; do
      soft=0
      if [[ "$users" == "200" && "$SOFT_200" -eq 1 ]]; then
        soft=1
      fi
      if ! run_stage "$users" "$soft"; then
        failed=1
      fi
      echo ""
    done
  fi

  python3 - <<PY >"$REPORT"
import json
from pathlib import Path
stages = []
for p in sorted(Path("$STAGE_JSON_DIR").glob("*.json")):
    stages.append(json.loads(p.read_text()))
print(json.dumps({
    "stamp": "$STAMP",
    "mode": "$GATE_MODE",
    "stages": stages,
    "failed": bool($failed),
}, indent=2))
PY

  {
    echo "CXR LOAD GATE — $STAMP ($GATE_MODE)"
    echo "Report: $REPORT"
    python3 - <<PY
import json
for s in json.load(open("$REPORT"))["stages"]:
    st = "PASS" if s["pass"] else "FAIL"
    print(f"  [{st}] users={s['users_target']} rps={s['max_rps']:.1f} p95={s['max_p95_ms']:.0f}ms collapses={s['collapse_count']}")
PY
  } | tee "$SUMMARY"

  if [[ "$failed" -eq 0 ]]; then
    echo "GATE PASSED"
    exit 0
  fi
  echo "GATE FAILED — see $REPORT"
  exit 1
}

main
