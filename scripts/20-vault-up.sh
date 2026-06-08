#!/usr/bin/env bash
# SW.17 — Start Vault dev server.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if command -v docker-compose &>/dev/null; then
  DC=(docker-compose)
else
  DC=(docker compose)
fi
"${DC[@]}" -f compose.vault.yaml up -d
echo ""
echo "Vault UI/API:  http://localhost:8200"
echo "Root token:    cxr-bootcamp-root  (dev only)"
echo ""
echo "Seed CXR secrets:  ./scripts/20-vault-smoke.sh"
echo "Secret map:        lab/vault/cxr-secret-map.json"
echo "Evidence:          evidence/SW17-vault-verify-2026-05-31.md"
echo "Manual:            docs/CXR-VAULT-LAB-MANUAL.pdf (./scripts/build-vault-manual-pdf.sh)"
