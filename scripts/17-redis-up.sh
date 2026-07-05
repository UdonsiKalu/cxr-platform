#!/usr/bin/env bash
# SW.14 — Start Redis for cache-aside lab.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if command -v docker-compose &>/dev/null; then
  DC=(docker-compose)
else
  DC=(docker compose)
fi
"${DC[@]}" -f "$ROOT/compose/labs/redis.yaml" up -d
echo ""
echo "Redis CLI:       localhost:6379"
echo "Redis Insight:   http://localhost:5540  (UI — see manual for first-time connect)"
echo "Cache-aside demo: ./lab/redis-cache-aside.sh"
echo ""
echo "Insight connect (once): Host redis · Port 6379 · Database alias cxr-lab"
echo "  Then Browser → keys → cxr:claim:analyzed:demo-1 (run cache-aside first)"
echo ""
echo "Smoke test:       ./scripts/17-redis-smoke.sh"
echo "Evidence:         evidence/SW14-redis-verify-2026-05-31.md"
echo "Manual:           docs/manuals/redis/manual.pdf (./scripts/build-redis-manual-pdf.sh)"
