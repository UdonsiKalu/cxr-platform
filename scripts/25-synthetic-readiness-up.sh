#!/usr/bin/env bash
# Synthetic operational-readiness traffic → :8251 analyze + Prometheus :9103
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GEN="$ROOT/observe/synthetic-traffic/readiness_generator.py"
VENV="$ROOT/observe/synthetic-traffic/.venv"
PORT="${CXR_SYNTHETIC_METRICS_PORT:-9103}"
PID_FILE="/tmp/cxr-synthetic-readiness-${PORT}.pid"
LOG_FILE="/tmp/cxr-synthetic-readiness-${PORT}.log"

metrics_up() {
  curl -sf -o /dev/null --connect-timeout 2 "http://127.0.0.1:${PORT}/metrics" 2>/dev/null
}

target_up() {
  local base="${CXR_SYNTHETIC_TARGET_URL:-http://127.0.0.1:8251}"
  curl -sf -o /dev/null --connect-timeout 3 "${base}/live-ops" 2>/dev/null
}

ensure_venv() {
  if [[ ! -x "$VENV/bin/python" ]]; then
    echo "Creating synthetic-traffic venv..."
    python3 -m venv "$VENV"
    "$VENV/bin/pip" install -q -r "$ROOT/observe/synthetic-traffic/requirements.txt"
  fi
}

stop_gen() {
  if [[ -f "$PID_FILE" ]]; then
    kill "$(cat "$PID_FILE")" 2>/dev/null || true
    rm -f "$PID_FILE"
  fi
  pkill -f "observe/synthetic-traffic/readiness_generator.py" 2>/dev/null || true
}

case "${1:-start}" in
  check|status)
    if metrics_up; then
      echo "synthetic-readiness up: http://127.0.0.1:${PORT}/metrics"
      curl -sf "http://127.0.0.1:${PORT}/metrics" | grep -E '^synthetic_' | head -8 || true
      exit 0
    fi
    echo "Not reachable on :${PORT} — run: $0 start" >&2
    exit 1
    ;;
  stop)
    stop_gen
    echo "Stopped synthetic-readiness on :${PORT}"
    ;;
  start|--foreground)
    stop_gen
    ensure_venv
    export CXR_SYNTHETIC_TARGET_URL="${CXR_SYNTHETIC_TARGET_URL:-http://127.0.0.1:8251}"
    export CXR_SYNTHETIC_METRICS_PORT="$PORT"
    export CXR_SYNTHETIC_ACTIVE_USERS="${CXR_SYNTHETIC_ACTIVE_USERS:-3}"
    export CXR_SYNTHETIC_PROFILE="${CXR_SYNTHETIC_PROFILE:-operational_readiness}"

    if ! target_up; then
      echo "WARN: ${CXR_SYNTHETIC_TARGET_URL} not reachable — start cxr-rehearsal-dev or cxr-dev.sh up first" >&2
    fi

    if [[ "${1:-}" == "--foreground" ]]; then
      exec "$VENV/bin/python" "$GEN"
    fi
    echo "Starting synthetic-readiness (target=${CXR_SYNTHETIC_TARGET_URL}, metrics=:${PORT})"
    nohup "$VENV/bin/python" "$GEN" >"$LOG_FILE" 2>&1 &
    echo $! >"$PID_FILE"
    for _ in $(seq 1 15); do
      metrics_up && break
      sleep 1
    done
    if metrics_up; then
      echo "synthetic-readiness ready: http://127.0.0.1:${PORT}/metrics (log: $LOG_FILE)"
    else
      echo "WARN: generator started but :${PORT} not responding — see $LOG_FILE" >&2
      exit 1
    fi
    ;;
  *)
    echo "Usage: $0 [start|check|status|stop|--foreground]" >&2
    exit 1
    ;;
esac
