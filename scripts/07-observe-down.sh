#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if command -v docker-compose &>/dev/null; then
  docker-compose -f compose.observe.yaml down "$@"
else
  docker compose -f compose.observe.yaml down "$@"
fi
echo "Observe stack stopped (Prometheus :9090, Grafana :3001)."
