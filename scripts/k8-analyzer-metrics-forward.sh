#!/usr/bin/env bash
# Port-forward each cxr-analyzer pod :8766 for Prometheus scrape (PERF-008 /metrics).
# One host port per pod (8767+) so sum(inflight) reflects the whole deployment.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/bin:${PATH:-}"
NS="${CXR_K8_NAMESPACE:-cxr-ui}"
BASE_PORT="${CXR_ANALYZER_METRICS_PORT:-8767}"
SVC_PORT="${CXR_ANALYZER_SERVICE_PORT:-8766}"
MAX_PODS="${CXR_ANALYZER_METRICS_MAX_PODS:-16}"
PIDFILE="/tmp/cxr-k8-analyzer-metrics-forward.pid"
LOG="/tmp/cxr-k8-analyzer-metrics-forward.log"
TARGETS_FILE="$ROOT/observe/prometheus/analyzer_targets.json"

stop() {
  if [[ -f "$PIDFILE" ]]; then
    while read -r pid; do
      [[ -n "$pid" ]] && kill "$pid" 2>/dev/null || true
    done <"$PIDFILE"
    rm -f "$PIDFILE"
  fi
  pkill -f "kubectl port-forward.*cxr-analyzer" 2>/dev/null || true
  for ((port = BASE_PORT; port < BASE_PORT + MAX_PODS; port++)); do
    if command -v fuser &>/dev/null; then
      fuser -k "${port}/tcp" 2>/dev/null || true
    fi
  done
}

write_targets() {
  local ports_csv="$1"
  mkdir -p "$(dirname "$TARGETS_FILE")"
  python3 - <<PY
import json
ports = [int(p) for p in "${ports_csv}".split(",") if p.strip()]
if not ports:
    json.dump([], open("$TARGETS_FILE", "w"))
else:
    json.dump([{
        "targets": [f"host.docker.internal:{p}" for p in ports],
        "labels": {"cluster": "docker-desktop", "service": "cxr-analyzer"},
    }], open("$TARGETS_FILE", "w"), indent=2)
PY
}

start() {
  stop
  : >"$PIDFILE"
  local pods=()
  mapfile -t pods < <(kubectl get pods -n "$NS" -l app=cxr-analyzer \
    --field-selector=status.phase=Running \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')

  if [[ ${#pods[@]} -eq 0 ]]; then
    echo "WARN: no running cxr-analyzer pods in $NS" >&2
    write_targets ""
    return 1
  fi

  local port=$BASE_PORT
  local ports=()
  for pod in "${pods[@]}"; do
    if ((port >= BASE_PORT + MAX_PODS)); then
      echo "WARN: max pod forwards ($MAX_PODS) — skipping $pod" >&2
      break
    fi
    nohup kubectl port-forward -n "$NS" "pod/$pod" "${port}:${SVC_PORT}" \
      --address=127.0.0.1 >>"$LOG" 2>&1 &
    echo $! >>"$PIDFILE"
    ports+=("$port")
    port=$((port + 1))
  done

  local ports_csv
  ports_csv="$(IFS=,; echo "${ports[*]}")"
  write_targets "$ports_csv"
  sleep 1
  echo "Analyzer metrics forward (${#pods[@]} pods):"
  for p in "${ports[@]}"; do
    echo "  http://127.0.0.1:${p}/metrics"
  done
  echo "  Prometheus targets: $TARGETS_FILE (log: $LOG)"
}

case "${1:-start}" in
  start) start ;;
  stop) stop ;;
  restart) stop; start ;;
  *)
    echo "Usage: $0 {start|stop|restart}" >&2
    exit 1
    ;;
esac
