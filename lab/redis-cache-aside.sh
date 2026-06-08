#!/usr/bin/env bash
# SW.14 — Cache-aside read of a static CXR JSON artifact (syllabus demo).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARTIFACT="${CXR_CACHE_ARTIFACT:-$ROOT/lab/fixtures/claim-analyzed.demo.json}"
CLAIM_ID="${CXR_CACHE_CLAIM_ID:-demo-1}"
TTL="${CXR_CACHE_TTL_SEC:-300}"
KEY="cxr:claim:analyzed:${CLAIM_ID}"

cid="$(docker ps -qf 'name=cxr-ops-lab-redis-1' | head -1)"
if [[ -z "$cid" ]]; then
  echo "Redis not running. Start: ./scripts/17-redis-up.sh" >&2
  exit 1
fi

rcli() { docker exec "$cid" redis-cli "$@"; }

echo "== SW.14 cache-aside =="
echo "Key:      $KEY"
echo "Artifact: $ARTIFACT"
echo "TTL:      ${TTL}s"
echo ""

if rcli EXISTS "$KEY" | grep -q '^1$'; then
  echo "1) CACHE HIT (key already warm)"
  rcli GET "$KEY"
  echo ""
  echo "2) INVALIDATE (DEL $KEY)"
  rcli DEL "$KEY" >/dev/null
  echo "   Key removed — next read is a miss."
  exit 0
fi

echo "1) CACHE MISS"
hit="$(rcli GET "$KEY")"
if [[ -n "$hit" && "$hit" != "(nil)" ]]; then
  echo "   unexpected value: $hit"
else
  echo "   (nil)"
fi

if [[ ! -f "$ARTIFACT" ]]; then
  echo "Artifact file missing: $ARTIFACT" >&2
  exit 1
fi

payload="$(tr -d '\n' < "$ARTIFACT" | sed 's/  */ /g')"
echo ""
echo "2) LOAD FROM SOURCE (static JSON file — stand-in for DB/API)"
echo "   $payload"
echo ""
echo "3) CACHE WRITE (SETEX ${TTL}s)"
rcli SETEX "$KEY" "$TTL" "$payload" >/dev/null
echo ""
echo "4) CACHE HIT"
rcli GET "$KEY"
echo ""
echo "Done. Invalidate early: docker exec $cid redis-cli DEL $KEY"
