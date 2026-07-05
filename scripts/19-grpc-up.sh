#!/usr/bin/env bash
# SW.16 — Start ClaimAnalysis gRPC server + grpcui browser.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if command -v docker-compose &>/dev/null; then
  DC=(docker-compose)
else
  DC=(docker compose)
fi
"${DC[@]}" -f "$ROOT/compose/labs/grpc.yaml" up -d --build
# grpcui can crash if it starts before reflection is registered — ensure clean attach.
"${DC[@]}" -f "$ROOT/compose/labs/grpc.yaml" restart grpc-ui 2>/dev/null || true
sleep 3
echo ""
echo "gRPC server:  localhost:50051  (ClaimAnalysis)"
echo "grpcui:       http://localhost:8090  (browser — pick service, Invoke)"
echo ""
echo "Golden RPC:   GetClaimStatus claim_id=demo-1; AnalyzeClaim (see lab/grpc/request-golden.json)"
echo "Smoke test:   ./scripts/19-grpc-smoke.sh"
echo "Evidence:     evidence/SW16-grpc-verify-2026-05-31.md"
echo "Manual:       docs/manuals/grpc/manual.pdf (./scripts/build-grpc-manual-pdf.sh)"
