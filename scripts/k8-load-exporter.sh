#!/usr/bin/env bash
# Host Prometheus exporter: Locust :8092 + kubectl (HPA, metrics-server top) → :9102/metrics
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/bin:${PATH:-}"
# shellcheck source=lib/kind-common.sh
source "$ROOT/scripts/lib/kind-common.sh"

PORT="${CXR_LOAD_EXPORTER_PORT:-9102}"
PID_FILE="/tmp/cxr-load-exporter-${PORT}.pid"
LOG_FILE="/tmp/cxr-load-exporter-${PORT}.log"
EXPORTER="$ROOT/observe/cxr-load-exporter/exporter.py"
VENV="$ROOT/observe/cxr-load-exporter/.venv"

require_kubectl "$ROOT"

exporter_up() {
  curl -sf -o /dev/null --connect-timeout 2 "http://127.0.0.1:${PORT}/metrics" 2>/dev/null
}

ensure_venv() {
  if [[ ! -x "$VENV/bin/python" ]]; then
    echo "Creating cxr-load-exporter venv..."
    python3 -m venv "$VENV"
    "$VENV/bin/pip" install -q -r "$ROOT/observe/cxr-load-exporter/requirements.txt"
  fi
}

stop_exporter() {
  if [[ -f "$PID_FILE" ]]; then
    kill "$(cat "$PID_FILE")" 2>/dev/null || true
    rm -f "$PID_FILE"
  fi
  pkill -f "observe/cxr-load-exporter/exporter.py" 2>/dev/null || true
}

case "${1:-start}" in
  check)
    if exporter_up; then
      echo "cxr-load-exporter up: http://127.0.0.1:${PORT}/metrics"
      exit 0
    fi
    echo "Not reachable on :${PORT} — run: $0 start" >&2
    exit 1
    ;;
  stop)
    stop_exporter
    echo "Stopped cxr-load-exporter on :${PORT}"
    ;;
  start|--foreground)
    stop_exporter
    ensure_venv
    export CXR_LOCUST_URL="${CXR_LOCUST_URL:-http://127.0.0.1:8092}"
    export CXR_K8_NAMESPACE="${CXR_K8_NAMESPACE:-cxr-ui}"
    export CXR_LOAD_EXPORTER_PORT="$PORT"
    export CXR_LOAD_EXPORTER_INTERVAL="${CXR_LOAD_EXPORTER_INTERVAL:-5}"
    if [[ "${1:-}" == "--foreground" ]]; then
      exec "$VENV/bin/python" "$EXPORTER"
    fi
    echo "Starting cxr-load-exporter on :${PORT} (locust=${CXR_LOCUST_URL})"
    nohup "$VENV/bin/python" "$EXPORTER" >"$LOG_FILE" 2>&1 &
    echo $! >"$PID_FILE"
    for _ in $(seq 1 15); do
      exporter_up && break
      sleep 1
    done
    if exporter_up; then
      echo "cxr-load-exporter ready: http://127.0.0.1:${PORT}/metrics (log: $LOG_FILE)"
    else
      echo "WARN: exporter started but :${PORT} not responding — see $LOG_FILE" >&2
      exit 1
    fi
    ;;
  *)
    echo "Usage: $0 [start|check|stop|--foreground]" >&2
    exit 1
    ;;
esac
