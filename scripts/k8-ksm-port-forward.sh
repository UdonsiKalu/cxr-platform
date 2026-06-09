#!/usr/bin/env bash
# Port-forward kube-state-metrics for Prometheus (compose) on host :9091.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/bin:${PATH:-}"
# shellcheck source=lib/kind-common.sh
source "$ROOT/scripts/lib/kind-common.sh"

PORT="${CXR_KSM_METRICS_PORT:-9091}"
PID_FILE="/tmp/cxr-k8-ksm-forward-${PORT}.pid"
LOG_FILE="/tmp/cxr-k8-ksm-forward-${PORT}.log"

require_kubectl "$ROOT"

if ! kubectl get svc kube-state-metrics -n kube-system &>/dev/null; then
  echo "kube-state-metrics not found — run $ROOT/scripts/10-kube-state-metrics-install.sh" >&2
  exit 1
fi

ksm_up() {
  curl -sf -o /dev/null --connect-timeout 2 "http://127.0.0.1:${PORT}/metrics" 2>/dev/null
}

stop_forward() {
  if [[ -f "$PID_FILE" ]]; then
    kill "$(cat "$PID_FILE")" 2>/dev/null || true
    rm -f "$PID_FILE"
  fi
  pkill -f "kubectl port-forward.*kube-state-metrics.*${PORT}:8080" 2>/dev/null || true
}

case "${1:-start}" in
  check)
    if ksm_up; then
      echo "kube-state-metrics metrics up: http://127.0.0.1:${PORT}/metrics"
      exit 0
    fi
    echo "Not reachable on :${PORT} — run: $0 start" >&2
    exit 1
    ;;
  stop)
    stop_forward
    echo "Stopped KSM port-forward on :${PORT}"
    ;;
  start|--foreground)
    stop_forward
    if [[ "${1:-}" == "--foreground" ]]; then
      exec kubectl port-forward -n kube-system svc/kube-state-metrics \
        "${PORT}:8080" --address=127.0.0.1
    fi
    echo "Starting kube-state-metrics forward :${PORT} → kube-system/kube-state-metrics:8080"
    nohup kubectl port-forward -n kube-system svc/kube-state-metrics \
      "${PORT}:8080" --address=127.0.0.1 >"$LOG_FILE" 2>&1 &
    echo $! >"$PID_FILE"
    for _ in $(seq 1 15); do
      ksm_up && break
      sleep 1
    done
    if ksm_up; then
      echo "KSM metrics ready: http://127.0.0.1:${PORT}/metrics (log: $LOG_FILE)"
    else
      echo "WARN: forward started but :${PORT} not responding yet — see $LOG_FILE" >&2
      exit 1
    fi
    ;;
  *)
    echo "Usage: $0 [start|check|stop|--foreground]" >&2
    exit 1
    ;;
esac
