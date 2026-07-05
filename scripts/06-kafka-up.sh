#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if command -v docker-compose &>/dev/null; then
  DC=(docker-compose)
else
  DC=(docker compose)
fi
"${DC[@]}" -f "$ROOT/compose/labs/kafka.yaml" up -d
echo ""
echo "Kafka UI (browser):  http://localhost:8082"
echo "Kafka broker (CLI):  localhost:9092  (not HTTP — use UI or kafka-topics)"
echo ""
echo "Create topic:"
echo "  docker exec -it \$(docker ps -qf name=cxr-ops-lab-kafka) kafka-topics --create --bootstrap-server localhost:9092 --topic cxr.claims.events --if-not-exists"
