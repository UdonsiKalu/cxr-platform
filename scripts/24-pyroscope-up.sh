#!/usr/bin/env bash
# PROF-001 — Optional Pyroscope (continuous profiling). Not required for LOAD gate.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

case "${1:-up}" in
  up)
    docker compose -f "$ROOT/compose.observe.yaml" --profile pyroscope up -d pyroscope
    echo "Pyroscope UI: http://127.0.0.1:4040"
    echo "Point analyzer at PYROSCOPE_SERVER=http://host.docker.internal:4040 when instrumented."
    ;;
  down)
    docker compose -f "$ROOT/compose.observe.yaml" --profile pyroscope stop pyroscope 2>/dev/null || true
    ;;
  check)
    code=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 2 http://127.0.0.1:4040/ 2>/dev/null || echo "000")
    [[ "$code" == "200" ]] && echo "Pyroscope up :4040" && exit 0
    echo "Pyroscope down — run: $0 up" >&2
    exit 1
    ;;
  *)
    echo "Usage: $0 [up|down|check]" >&2
    exit 1
    ;;
esac
