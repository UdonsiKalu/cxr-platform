#!/usr/bin/env bash
# Live Ops Fault Gym — scenario inject / recover on top of 26-live-ops-stream-up.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGING_ROOT="${CXR_STAGING:-$(cd "$ROOT/.." && pwd)}"
PORTFOLIO="${CXR_PORTFOLIO:-${STAGING_ROOT}/cxr-portfolio}"
STREAM="$ROOT/scripts/26-live-ops-stream-up.sh"
STATE_FILE="/tmp/cxr-live-ops-scenario.json"
INJECT_LOG="/tmp/cxr-live-ops-scenario-inject.log"
REHEARSAL_PORT="${CXR_REHEARSAL_PORT:-8251}"
ANALYZER_PORT="${CXR_ANALYZER_PORT:-8766}"
QDRANT_PORT="${CXR_QDRANT_PORT:-6333}"

CHAOS_DIR="${PORTFOLIO}/investigations/kill-analyzer-under-traffic"
KILL_SCRIPT="${CHAOS_DIR}/kill-analyzer.sh"
RESTART_SCRIPT="${CHAOS_DIR}/restart-analyzer-wait-warm.sh"

write_state() {
  local scenario="$1"
  local phase="$2"
  local load="${3:-normal}"
  local ts
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  python3 -c "
import json, sys
json.dump({
  'scenario': sys.argv[1],
  'phase': sys.argv[2],
  'loadProfile': sys.argv[3],
  'startedAt': sys.argv[4],
}, sys.stdout, indent=2)
" "$scenario" "$phase" "$load" "$ts" >"$STATE_FILE"
}

read_state_field() {
  local field="$1"
  python3 -c "
import json, pathlib, sys
p = pathlib.Path('${STATE_FILE}')
if not p.exists():
    sys.exit(0)
d = json.loads(p.read_text())
print(d.get('${field}', ''))
" 2>/dev/null || true
}

qdrant_container() {
  local name
  for name in cxr-qdrant cxr-qdrant-outage-lab qdrant-1; do
    if docker ps -a --format '{{.Names}}' 2>/dev/null | grep -qx "$name"; then
      echo "$name"
      return 0
    fi
  done
  docker ps --format '{{.Names}} {{.Ports}}' 2>/dev/null | grep -E ":${QDRANT_PORT}->" | awk '{print $1}' | head -1
}

stop_qdrant() {
  local c
  c="$(qdrant_container || true)"
  if [[ -n "$c" ]] && docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$c"; then
    echo "Stopping Qdrant container: $c"
    docker stop "$c" >/dev/null
    return 0
  fi
  echo "WARN: no running Qdrant container on :${QDRANT_PORT}" >&2
}

start_qdrant() {
  local c
  c="$(qdrant_container || true)"
  if [[ -n "$c" ]]; then
    echo "Starting Qdrant container: $c"
    docker start "$c" >/dev/null || true
    for _ in $(seq 1 30); do
      curl -sf "http://127.0.0.1:${QDRANT_PORT}/" >/dev/null 2>&1 && return 0
      sleep 1
    done
  fi
  echo "WARN: Qdrant not reachable on :${QDRANT_PORT}" >&2
}

inject_scenario() {
  local scenario="$1"
  case "$scenario" in
    healthy|load-saturation)
      write_state "$scenario" "healthy" "$(read_state_field loadProfile)"
      ;;
    chaos-analyzer-kill)
      write_state "$scenario" "injecting" "dramatic"
      echo "Waiting 15s for load before analyzer kill..." >>"$INJECT_LOG"
      sleep 15
      if [[ -x "$KILL_SCRIPT" ]]; then
        CXR_ANALYZER_PORT="$ANALYZER_PORT" "$KILL_SCRIPT" >>"$INJECT_LOG" 2>&1
      else
        fuser -k "${ANALYZER_PORT}/tcp" 2>/dev/null || true
      fi
      write_state "$scenario" "faulted" "dramatic"
      echo "Analyzer kill complete" >>"$INJECT_LOG"
      ;;
    dep-qdrant-down)
      write_state "$scenario" "injecting" "normal"
      stop_qdrant >>"$INJECT_LOG" 2>&1
      write_state "$scenario" "faulted" "normal"
      ;;
    *)
      echo "Unknown scenario: $scenario" >&2
      exit 1
      ;;
  esac
}

recover_scenario() {
  local scenario="${1:-$(read_state_field scenario)}"
  scenario="${scenario:-healthy}"
  write_state "$scenario" "recovering" "$(read_state_field loadProfile)"
  local ok=0
  case "$scenario" in
    chaos-analyzer-kill|healthy)
      start_qdrant >>"$INJECT_LOG" 2>&1 || true
      if curl -sf "http://127.0.0.1:${ANALYZER_PORT}/health" | grep -q '"warmed":"true"'; then
        echo "Analyzer already warmed" >>"$INJECT_LOG"
      elif [[ -x "$RESTART_SCRIPT" ]]; then
        CXR_STAGING="$STAGING_ROOT" "$RESTART_SCRIPT" >>"$INJECT_LOG" 2>&1 || ok=1
      else
        echo "WARN: restart script missing" >>"$INJECT_LOG"
        ok=1
      fi
      ;;
    dep-qdrant-down)
      start_qdrant >>"$INJECT_LOG" 2>&1 || ok=1
      ;;
    load-saturation)
      CXR_REHEARSAL_PORT="$REHEARSAL_PORT" "$STREAM" profile normal >>"$INJECT_LOG" 2>&1 || ok=1
      ;;
    *)
      start_qdrant >>"$INJECT_LOG" 2>&1 || true
      ;;
  esac
  if [[ "$ok" -eq 0 ]]; then
    write_state "healthy" "healthy" "normal"
  else
    write_state "$scenario" "faulted" "$(read_state_field loadProfile)"
    echo "Recover incomplete — analyzer not warmed after 120s. Run: cxr up  OR  restart-analyzer-wait-warm.sh — see ${INJECT_LOG}" >&2
    exit 1
  fi
}

start_scenario() {
  local scenario="$1"
  local load="${2:-}"
  case "$scenario" in
    healthy)
      # Lightweight reset — do not block on analyzer warm (prior chaos may have killed :8766).
      start_qdrant >>"$INJECT_LOG" 2>&1 || true
      CXR_REHEARSAL_PORT="$REHEARSAL_PORT" "$STREAM" start normal
      write_state "healthy" "healthy" "normal"
      if ! curl -sf "http://127.0.0.1:${ANALYZER_PORT}/health" | grep -q '"warmed":"true"'; then
        echo "Healthy: starting analyzer warm in background (check :8766/health)" >>"$INJECT_LOG"
        if [[ -x "$RESTART_SCRIPT" ]]; then
          nohup env CXR_STAGING="$STAGING_ROOT" "$RESTART_SCRIPT" >>"$INJECT_LOG" 2>&1 &
        fi
      fi
      ;;
    chaos-analyzer-kill)
      CXR_REHEARSAL_PORT="$REHEARSAL_PORT" "$STREAM" start dramatic
      : >"$INJECT_LOG"
      nohup "$0" inject chaos-analyzer-kill >>"$INJECT_LOG" 2>&1 &
      write_state "$scenario" "injecting" "dramatic"
      ;;
    dep-qdrant-down)
      CXR_REHEARSAL_PORT="$REHEARSAL_PORT" "$STREAM" start normal
      : >"$INJECT_LOG"
      inject_scenario dep-qdrant-down >>"$INJECT_LOG" 2>&1
      ;;
    load-saturation)
      CXR_REHEARSAL_PORT="$REHEARSAL_PORT" "$STREAM" start dramatic
      write_state "$scenario" "faulted" "dramatic"
      ;;
    *)
      echo "Unknown scenario: $scenario" >&2
      exit 1
      ;;
  esac
}

case "${1:-status}" in
  list)
    echo "healthy chaos-analyzer-kill dep-qdrant-down load-saturation"
    ;;
  status)
    if [[ ! -f "$STATE_FILE" ]]; then
      echo '{"scenario":"healthy","phase":"healthy","loadProfile":"normal"}'
      exit 0
    fi
    cat "$STATE_FILE"
    ;;
  inject)
    inject_scenario "${2:?scenario required}"
    ;;
  recover)
    recover_scenario "${2:-}"
    ;;
  start)
    start_scenario "${2:-healthy}" "${3:-}"
    ;;
  *)
    echo "Usage: $0 {list|status|start <scenario>|recover [scenario]|inject <scenario>}" >&2
    exit 1
    ;;
esac
