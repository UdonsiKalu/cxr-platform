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
echo "Grafana    http://localhost:3001 (admin / see GF_SECURITY_ADMIN_PASSWORD in compose.observe.yaml)"
echo "Jaeger UI  http://localhost:16686  (SW.11 traces)"
echo "OTel HTTP  http://localhost:4318  (apps send OTLP here)"
echo ""
echo "Rehearsal with traces:"
echo "  export OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:4318"
echo "  export OTEL_SERVICE_NAME=cxr-ui-rehearsal"
echo "  cd ../cxr-ui-prune-rehearsal/cxr-ui && npm run dev:rehearsal"
echo "See .env.otel.example and docs/CXR-OTEL-LAB-MANUAL.md"
