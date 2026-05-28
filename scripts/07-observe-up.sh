#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if command -v docker-compose &>/dev/null; then
  docker-compose -f compose.observe.yaml up -d
else
  docker compose -f compose.observe.yaml up -d
fi
echo "Prometheus http://localhost:9090"
echo "Grafana http://localhost:3001 (admin / admin)"
echo "Add OTel (SW.11) later — collector → Jaeger sidecar on this compose network."
