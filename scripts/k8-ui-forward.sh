#!/usr/bin/env bash
# Idempotent CXR K8 UI port-forward on localhost:8081.
# Safe when cxr-k8-forward.service (systemd) or a prior kubectl forward is already up.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/bin:${PATH:-}"
# shellcheck source=lib/kind-common.sh
source "$ROOT/scripts/lib/kind-common.sh"

NS="${CXR_K8_NAMESPACE:-cxr-ui}"
PORT="${CXR_K8_UI_PORT:-8081}"
ADDR="${CXR_K8_UI_BIND:-127.0.0.1}"
MODE="${1:-check}"

require_kubectl "$ROOT"

ui_url="http://${ADDR}:${PORT}/"

ui_responds() {
  curl -sf -o /dev/null --connect-timeout 2 "$ui_url" 2>/dev/null
}

port_in_use() {
  ss -ltn 2>/dev/null | grep -q "${ADDR}:${PORT} "
}

clear_stale_listener() {
  if command -v fuser &>/dev/null; then
    fuser -k "${PORT}/tcp" 2>/dev/null || true
  else
    pkill -f "port-forward.*${PORT}:3000" 2>/dev/null || true
  fi
  sleep 1
}

start_foreground() {
  echo "Starting port-forward ${ADDR}:${PORT} → cxr-ui:3000 (Ctrl+C to stop)..."
  exec kubectl port-forward -n "$NS" svc/cxr-ui "${PORT}:3000" --address="$ADDR"
}

start_background() {
  echo "Starting port-forward ${ADDR}:${PORT} in background..."
  nohup kubectl port-forward -n "$NS" svc/cxr-ui "${PORT}:3000" --address="$ADDR" \
    >>/tmp/cxr-k8-ui-forward.log 2>&1 &
  for _ in $(seq 1 20); do
    ui_responds && return 0
    sleep 1
  done
  echo "ERROR: port-forward started but ${ui_url} not responding — see /tmp/cxr-k8-ui-forward.log" >&2
  return 1
}

case "$MODE" in
  check|--check)
    if ui_responds; then
      echo "CXR K8 UI already up: ${ui_url} (no second port-forward needed)"
      exit 0
    fi
    if port_in_use; then
      echo "Port ${ADDR}:${PORT} in use but UI not responding — run: $0 --restart"
      exit 1
    fi
    echo "CXR K8 UI not reachable on ${ui_url} — run: $0 --foreground or enable cxr-k8-forward.service"
    exit 1
    ;;
  --foreground|-f)
    if ui_responds; then
      echo "CXR K8 UI already up: ${ui_url}"
      echo "Tip: cxr-k8-forward.service may already be forwarding — no second kubectl needed."
      exit 0
    fi
    if port_in_use; then
      echo "Clearing stale listener on :${PORT}..."
      clear_stale_listener
    fi
    start_foreground
    ;;
  --background|-b)
    if ui_responds; then
      echo "CXR K8 UI already up: ${ui_url}"
      exit 0
    fi
    if port_in_use; then
      echo "Clearing stale listener on :${PORT}..."
      clear_stale_listener
    fi
    start_background
    echo "CXR K8 UI ready: ${ui_url}"
    ;;
  --restart)
    echo "Restarting port-forward on :${PORT}..."
    clear_stale_listener
    start_background
    echo "CXR K8 UI ready: ${ui_url}"
    ;;
  --help|-h)
    cat <<EOF
Usage: $0 [check|--foreground|--background|--restart]

  (default) check   Exit 0 if http://${ADDR}:${PORT}/ responds; else explain next step
  --foreground      Start kubectl port-forward (or exit 0 if already up)
  --background      Start detached forward (or exit 0 if already up)
  --restart         Kill :${PORT} listener and start fresh background forward

When cxr-k8-forward.service is active, use check only — do not run raw kubectl port-forward.
EOF
    ;;
  *)
    echo "Unknown mode: $MODE (try --help)" >&2
    exit 1
    ;;
esac
