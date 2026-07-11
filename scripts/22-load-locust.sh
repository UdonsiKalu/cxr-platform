#!/usr/bin/env bash
# Load lab — Locust web UI (http://localhost:8089 by default) or headless.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOCUST_DIR="$ROOT/load/locust"
VENV="$LOCUST_DIR/.venv"
HOST="${CXR_LOAD_URL:-http://127.0.0.1:3000}"
WEB_PORT="${CXR_LOCUST_WEB_PORT:-8089}"
MODE="${1:-start}"

locust_ui_up() {
  curl -sf -o /dev/null --connect-timeout 2 "http://127.0.0.1:${WEB_PORT}/" 2>/dev/null
}

running_locust_host() {
  local line
  line="$(ps aux 2>/dev/null | grep '[l]ocust.*--host' | grep -- "--web-port ${WEB_PORT}" | head -1 || true)"
  if [[ -z "$line" ]]; then
    line="$(ps aux 2>/dev/null | grep '[l]ocust.*--host' | head -1 || true)"
  fi
  if [[ -n "$line" ]]; then
    echo "$line" | sed -n 's/.*--host \([^ ]*\).*/\1/p'
  fi
}

clear_locust_port() {
  pkill -f "locust.*--web-port ${WEB_PORT}" 2>/dev/null || true
  if command -v fuser &>/dev/null; then
    fuser -k "${WEB_PORT}/tcp" 2>/dev/null || true
  fi
  sleep 1
}

ensure_venv() {
  if [[ ! -d "$VENV" ]]; then
    echo "Creating Locust venv in load/locust/.venv ..."
    python3 -m venv "$VENV"
    "$VENV/bin/pip" install -q --upgrade pip
    "$VENV/bin/pip" install -q -r "$LOCUST_DIR/requirements.txt"
  fi
}

if ! curl -sf -o /dev/null --connect-timeout 2 "${HOST}/claim-studio" 2>/dev/null; then
  echo "WARN CXR not reachable at ${HOST}/claim-studio" >&2
  echo "  K8: ./scripts/k8-ui-forward.sh check  (http://127.0.0.1:8081)" >&2
  echo "  Dev: npm run dev:rehearsal on :8251  OR  ./scripts/04-compose-up.sh :3000" >&2
fi

ensure_venv

case "$MODE" in
  check|--check)
    if locust_ui_up; then
      existing="$(running_locust_host || true)"
      echo "Locust UI already up: http://127.0.0.1:${WEB_PORT}/"
      if [[ -n "$existing" ]]; then
        echo "  Current target (--host): ${existing}"
        if [[ "$existing" != "$HOST" ]]; then
          echo "  Requested CXR_LOAD_URL=${HOST} — run: $0 --restart"
          exit 1
        fi
      fi
      exit 0
    fi
    echo "Locust UI not running on :${WEB_PORT} — run: CXR_LOAD_URL=${HOST} $0"
    exit 1
    ;;
  --restart)
    echo "Restarting Locust on :${WEB_PORT} → ${HOST} ..."
    clear_locust_port
    ;;
  --headless)
    echo "== CXR Locust headless =="
    echo "  Target: ${HOST}"
    echo "  Users:  ${CXR_LOCUST_USERS:-10}  spawn: ${CXR_LOCUST_SPAWN:-2}/s  time: ${CXR_LOCUST_TIME:-10m}"
    exec "$VENV/bin/locust" \
      -f "$LOCUST_DIR/locustfile.py" \
      --host "$HOST" \
      --headless \
      -u "${CXR_LOCUST_USERS:-10}" \
      -r "${CXR_LOCUST_SPAWN:-2}" \
      -t "${CXR_LOCUST_TIME:-10m}"
    ;;
  --autostart)
    echo "== CXR Locust autostart (web :${WEB_PORT}) =="
    echo "  Target: ${HOST}"
    echo "  Users:  ${CXR_LOCUST_USERS:-10}  spawn: ${CXR_LOCUST_SPAWN:-2}/s  time: ${CXR_LOCUST_TIME:-10m}"
    exec "$VENV/bin/locust" \
      -f "$LOCUST_DIR/locustfile.py" \
      --host "$HOST" \
      --web-host 127.0.0.1 \
      --web-port "${WEB_PORT}" \
      -u "${CXR_LOCUST_USERS:-10}" \
      -r "${CXR_LOCUST_SPAWN:-2}" \
      --run-time "${CXR_LOCUST_TIME:-10m}" \
      --autostart \
      --autoquit 5
    ;;
  --ramp-autostart)
    LOCUSTFILE="${CXR_LOCUST_RAMP_FILE:-$LOCUST_DIR/locustfile-ramp.py}"
    echo "== CXR Locust cumulative ramp [${CXR_RAMP_PROFILE:-lightweight_mixed}] (web :${WEB_PORT}) =="
    echo "  Target: ${HOST}"
    echo "  Ramp:   ${CXR_RAMP_START_USERS:-25} +${CXR_RAMP_STEP_USERS:-25} → ${CXR_RAMP_MAX_USERS:-200}"
    echo "  Tier:   ${CXR_RAMP_STAGE_SECONDS:-90}s  hold@max: ${CXR_RAMP_HOLD_AT_MAX_S:-120}s"
    echo "  Run:    ${CXR_LOCUST_TIME:-auto}"
    exec "$VENV/bin/locust" \
      -f "$LOCUSTFILE" \
      --host "$HOST" \
      --web-host 127.0.0.1 \
      --web-port "${WEB_PORT}" \
      --run-time "${CXR_LOCUST_TIME:-20m}" \
      --autostart \
      --autoquit 5
    ;;
  --help|-h)
    cat <<EOF
Usage: $0 [check|--restart|--headless]

  CXR_LOAD_URL          Target CXR UI (default http://127.0.0.1:3000)
                        K8 stack:  CXR_LOAD_URL=http://127.0.0.1:8081 $0
  CXR_LOCUST_WEB_PORT   Locust UI port (default 8089)
  CXR_LOCUST_USERS      Headless users (default 10)
  CXR_LOCUST_SPAWN      Headless spawn rate (default 2/s)
  CXR_LOCUST_TIME       Headless duration (default 10m)

Examples:
  CXR_LOAD_URL=http://127.0.0.1:8081 $0 check
  CXR_LOAD_URL=http://127.0.0.1:8081 $0 --restart
  CXR_LOAD_URL=http://127.0.0.1:8081 $0 --headless
EOF
    exit 0
    ;;
  start)
    if locust_ui_up; then
      existing="$(running_locust_host || true)"
      if [[ -z "$existing" || "$existing" == "$HOST" ]]; then
        echo "Locust UI already up: http://127.0.0.1:${WEB_PORT}/"
        echo "  Target: ${existing:-${HOST}}"
        echo "  Open UI and start swarm — or: $0 --restart to retarget ${HOST}"
        exit 0
      fi
      echo "Locust on :${WEB_PORT} targets ${existing}, not ${HOST}." >&2
      echo "  Run: CXR_LOAD_URL=${HOST} $0 --restart" >&2
      echo "  Or:  CXR_LOCUST_WEB_PORT=8090 CXR_LOAD_URL=${HOST} $0" >&2
      exit 1
    fi
    if ss -ltn 2>/dev/null | grep -q "127.0.0.1:${WEB_PORT} "; then
      echo "Clearing stale listener on :${WEB_PORT} ..."
      clear_locust_port
    fi
    ;;
  *)
    echo "Unknown mode: $MODE (try --help)" >&2
    exit 1
    ;;
esac

echo "== CXR Locust load =="
echo "  Target (--host): ${HOST}"
echo "  Locust UI:       http://127.0.0.1:${WEB_PORT}"
echo "  Start small:     5–10 users, spawn rate 1/s (K8 HPA: run k8-hpa-watch.sh in another terminal)"
echo "  Headless:        CXR_LOAD_URL=${HOST} $0 --headless"
echo ""

exec "$VENV/bin/locust" \
  -f "$LOCUST_DIR/locustfile.py" \
  --host "$HOST" \
  --web-host 127.0.0.1 \
  --web-port "$WEB_PORT"
