#!/usr/bin/env bash
# SW.16 — grpcui HTTP probe + in-container gRPC golden path.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if curl -sf "http://localhost:8090/" >/dev/null; then
  echo "OK  grpcui :8090"
else
  for _ in 1 2 3 4 5; do
    sleep 2
    curl -sf "http://localhost:8090/" >/dev/null && break
  done
  if curl -sf "http://localhost:8090/" >/dev/null; then
    echo "OK  grpcui :8090 (after retry)"
  else
    echo "FAIL grpcui :8090" >&2
    exit 1
  fi
fi

if command -v docker-compose &>/dev/null; then
  DC=(docker-compose)
else
  DC=(docker compose)
fi

"${DC[@]}" -f "$ROOT/compose/labs/grpc.yaml" exec -T grpc-analysis node client-smoke.mjs

echo ""
echo "Browser: http://localhost:8090 → ClaimAnalysis → AnalyzeClaim → claim_id demo-1"
