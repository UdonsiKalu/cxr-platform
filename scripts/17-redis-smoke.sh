#!/usr/bin/env bash
# SW.14 — Health check + quick cache-aside proof.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

cid="$(docker ps -qf 'name=cxr-ops-lab-redis-1' | head -1)"
if [[ -z "$cid" ]]; then
  echo "FAIL Redis container not running. Run: ./scripts/17-redis-up.sh" >&2
  exit 1
fi

if docker exec "$cid" redis-cli ping | grep -q PONG; then
  echo "OK  redis-cli PING → PONG"
else
  echo "FAIL redis PING" >&2
  exit 1
fi

if curl -sf --max-time 15 http://localhost:5540/ >/dev/null 2>&1; then
  echo "OK  Redis Insight http://localhost:5540"
else
  echo "WARN Redis Insight not ready yet — wait ~30s and open http://localhost:5540"
fi

if ./lab/redis-cache-aside.sh >/tmp/cxr-redis-cache-aside.log 2>&1; then
  if grep -q "CACHE HIT" /tmp/cxr-redis-cache-aside.log; then
    echo "OK  cache-aside script (miss → load → hit)"
  else
    echo "WARN cache-aside ran but no CACHE HIT line — check /tmp/cxr-redis-cache-aside.log"
  fi
else
  echo "FAIL cache-aside script" >&2
  cat /tmp/cxr-redis-cache-aside.log >&2
  exit 1
fi

echo ""
echo "Browser UI: http://localhost:5540 → connect redis:6379 → browse key cxr:claim:analyzed:demo-1"
