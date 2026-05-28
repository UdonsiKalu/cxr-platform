#!/usr/bin/env bash
set -euo pipefail
TOPIC="${CXR_KAFKA_TOPIC:-cxr.claims.events}"
MSG='{"event":"claim.analyzed","claim_id":"demo-1","status":"ok","ts":"2026-05-25T00:00:00Z"}'
docker exec "$(docker ps -qf name=cxr-ops-lab-kafka-1)" kafka-console-producer \
  --bootstrap-server localhost:9092 \
  --topic "$TOPIC" \
  <<< "$MSG"
echo "Published to $TOPIC"
