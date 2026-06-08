#!/usr/bin/env bash
# SW.15 — Start Apollo Gateway + claims/policies subgraphs.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if command -v docker-compose &>/dev/null; then
  DC=(docker-compose)
else
  DC=(docker compose)
fi
"${DC[@]}" -f compose.graphql.yaml up -d --build
echo ""
echo "GraphQL gateway:  http://localhost:4000/graphql  (Apollo Sandbox in browser)"
echo "Claims subgraph:  http://localhost:4001/graphql"
echo "Policies subgraph: http://localhost:4002/graphql"
echo ""
echo "Golden query:     lab/graphql/query-golden.graphql"
echo "Smoke test:       ./scripts/18-graphql-smoke.sh"
echo "Evidence:         evidence/SW15-graphql-verify-2026-05-31.md"
echo "Manual:           docs/CXR-GRAPHQL-LAB-MANUAL.pdf (./scripts/build-graphql-manual-pdf.sh)"
