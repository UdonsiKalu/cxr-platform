#!/usr/bin/env bash
# Live Ops streaming — Locust + synthetic readiness + cxr-load-exporter → Prometheus → :8251/live-ops
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REHEARSAL_PORT="${CXR_REHEARSAL_PORT:-8251}"
LOCUST_PORT="${CXR_LOCUST_WEB_PORT:-8089}"
LOAD_URL="http://127.0.0.1:${REHEARSAL_PORT}"
LOCUST_URL="http://127.0.0.1:${LOCUST_PORT}"
EXPORTER_PORT="${CXR_LOAD_EXPORTER_PORT:-9102}"
SYNTH_PORT="${CXR_SYNTHETIC_METRICS_PORT:-9103}"
PROFILE_FILE="/tmp/cxr-live-ops-simulation-profile"

apply_sim_profile() {
  local profile="${1:-normal}"
  case "$profile" in
    dramatic)
      export CXR_SYNTHETIC_ACTIVE_USERS=12
      export CXR_SYNTHETIC_MIN_INTERVAL_S=1
      export CXR_SYNTHETIC_MAX_INTERVAL_S=4
      export CXR_LOCUST_USERS=80
      export CXR_LOCUST_SPAWN=5
      export CXR_LOCUST_TIME=60m
      ;;
    normal|*)
      profile="normal"
      export CXR_SYNTHETIC_ACTIVE_USERS=5
      export CXR_SYNTHETIC_MIN_INTERVAL_S=5
      export CXR_SYNTHETIC_MAX_INTERVAL_S=12
      export CXR_LOCUST_USERS=15
      export CXR_LOCUST_SPAWN=2
      export CXR_LOCUST_TIME=30m
      ;;
  esac
  echo "$profile" >"$PROFILE_FILE"
}

stream_start() {
  local profile="${1:-$(cat "$PROFILE_FILE" 2>/dev/null || echo normal)}"
  apply_sim_profile "$profile"
  echo "== Live Ops stream up (profile: ${profile}) =="
  if ! curl -sf -o /dev/null --connect-timeout 3 "${LOAD_URL}/live-ops"; then
    echo "WARN: rehearsal :${REHEARSAL_PORT} not up — run: ~/staging/cxr-dev.sh up" >&2
  fi
  CXR_SYNTHETIC_ACTIVE_USERS="$CXR_SYNTHETIC_ACTIVE_USERS" \
  CXR_SYNTHETIC_MIN_INTERVAL_S="$CXR_SYNTHETIC_MIN_INTERVAL_S" \
  CXR_SYNTHETIC_MAX_INTERVAL_S="$CXR_SYNTHETIC_MAX_INTERVAL_S" \
    "$ROOT/scripts/25-synthetic-readiness-up.sh" start
  echo "Starting Locust :${LOCUST_PORT} autostart → ${LOAD_URL} (${CXR_LOCUST_USERS} users)"
  pkill -f "locust.*--web-port ${LOCUST_PORT}" 2>/dev/null || true
  sleep 1
  CXR_LOAD_URL="${LOAD_URL}" \
  CXR_LOCUST_USERS="$CXR_LOCUST_USERS" \
  CXR_LOCUST_SPAWN="$CXR_LOCUST_SPAWN" \
  CXR_LOCUST_TIME="$CXR_LOCUST_TIME" \
    nohup "$ROOT/scripts/22-load-locust.sh" --autostart >"/tmp/cxr-locust-${LOCUST_PORT}-autostart.log" 2>&1 &
  for _ in $(seq 1 45); do
    if curl -sf -o /dev/null --connect-timeout 2 "${LOCUST_URL}/"; then
      sleep 3
      break
    fi
    sleep 1
  done
  CXR_LOCUST_URL="${LOCUST_URL}" \
  CXR_LOAD_EXPORTER_PORT="${EXPORTER_PORT}" \
    "$ROOT/scripts/k8-load-exporter.sh" start
  echo ""
  echo "Live Ops stream (${profile}):"
  echo "  Rehearsal     ${LOAD_URL}/live-ops"
  echo "  Locust UI     ${LOCUST_URL}"
  echo "  Synthetic     http://127.0.0.1:${SYNTH_PORT}/metrics"
  echo "  Load exporter http://127.0.0.1:${EXPORTER_PORT}/metrics"
  echo "  Prometheus    http://127.0.0.1:9090"
  echo "  API           ${LOAD_URL}/api/live-ops/metrics"
}

case "${1:-start}" in
  start)
    stream_start "${2:-}"
    ;;
  profile|set-profile)
    stream_start "${2:-normal}"
    ;;
  get-profile)
    cat "$PROFILE_FILE" 2>/dev/null || echo "normal"
    ;;
  stop)
    "$ROOT/scripts/k8-load-exporter.sh" stop || true
    "$ROOT/scripts/25-synthetic-readiness-up.sh" stop || true
    pkill -f "locust.*--web-port ${LOCUST_PORT}" 2>/dev/null || true
    echo "Stopped Live Ops stream (Locust :${LOCUST_PORT}, synthetic :${SYNTH_PORT}, exporter :${EXPORTER_PORT})"
    ;;
  status|check)
    echo "== Live Ops stream status =="
    curl -sf -o /dev/null --connect-timeout 2 "${LOAD_URL}/live-ops" && echo "Rehearsal     UP  ${LOAD_URL}" || echo "Rehearsal     DOWN :${REHEARSAL_PORT}"
    "$ROOT/scripts/25-synthetic-readiness-up.sh" status 2>/dev/null || echo "Synthetic     DOWN :${SYNTH_PORT}"
    curl -sf -o /dev/null --connect-timeout 2 "${LOCUST_URL}/" && echo "Locust        UP  ${LOCUST_URL}" || echo "Locust        DOWN :${LOCUST_PORT}"
    "$ROOT/scripts/k8-load-exporter.sh" check 2>/dev/null || echo "Load exporter DOWN :${EXPORTER_PORT}"
    curl -sf "${LOAD_URL}/api/live-ops/metrics" | python3 -c "
import sys,json
d=json.load(sys.stdin)
print('Metrics API  ', 'live' if d.get('live') else 'mock', 'locust' if d.get('locustLive') else 'no-locust', 'synthetic' if d.get('syntheticLive') else '')
" 2>/dev/null || echo "Metrics API   unreachable"
    echo "Profile       $(cat "$PROFILE_FILE" 2>/dev/null || echo normal)"
    ;;
  *)
    echo "Usage: $0 [start [normal|dramatic]|stop|status|profile normal|dramatic|get-profile]" >&2
    exit 1
    ;;
esac
