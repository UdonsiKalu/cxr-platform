#!/usr/bin/env bash
# SW.12 — Start Elasticsearch + Kibana + Filebeat (log shipping).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if command -v docker-compose &>/dev/null; then
  DC=(docker-compose)
else
  DC=(docker compose)
fi
"${DC[@]}" -f compose.elk.yaml up -d
echo ""
echo "Elasticsearch:  http://localhost:9200"
echo "Kibana UI:      http://localhost:5601"
echo ""
echo "Generate cxr-ui logs: http://localhost:3000/claim-studio (compose must be up)"
echo "Smoke test:       ./scripts/16-elk-smoke.sh"
echo "Evidence:         evidence/SW12-elk-verify-2026-05-29.md"
