#!/usr/bin/env bash
# SW.12 — Health check for ELK stack.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail=0
check() {
  local name="$1"
  shift
  if "$@"; then
    echo "OK  $name"
  else
    echo "FAIL $name" >&2
    fail=1
  fi
}

check "Elasticsearch cluster" curl -sf "http://localhost:9200/_cluster/health?wait_for_status=yellow&timeout=60s" >/dev/null
kibana_ok=0
for _ in $(seq 1 30); do
  if curl -sf "http://localhost:5601/api/status" >/dev/null; then
    kibana_ok=1
    break
  fi
  sleep 2
done
if [[ "$kibana_ok" -eq 1 ]]; then
  echo "OK  Kibana status"
else
  echo "FAIL Kibana status (still starting?)" >&2
  fail=1
fi

if docker ps --format '{{.Names}}' | grep -q filebeat; then
  echo "OK  filebeat container running"
else
  echo "FAIL filebeat container" >&2
  fail=1
fi

indices="$(curl -sf 'http://localhost:9200/_cat/indices?h=index' 2>/dev/null | grep -E 'filebeat|logs' || true)"
if [[ -n "$indices" ]]; then
  echo "OK  Elasticsearch indices:"
  echo "$indices" | sed 's/^/    /'
else
  echo "WARN no filebeat-* index yet — open :3000, hit Claim Studio, wait ~30s, re-run"
fi

if docker ps --format '{{.Names}}' | grep -qE 'cxr-ui'; then
  echo "OK  cxr-ui container present (log source)"
else
  echo "WARN no cxr-ui container — start ./scripts/04-compose-up.sh for log shipping target"
fi

echo ""
echo "Kibana: http://localhost:5601 → Discover → create data view filebeat-* → search claim-studio"
exit "$fail"
