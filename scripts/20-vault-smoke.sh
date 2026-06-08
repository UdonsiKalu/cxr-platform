#!/usr/bin/env bash
# SW.17 — Vault health + seed + read golden secret.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if curl -sf "http://localhost:8200/v1/sys/health" >/dev/null; then
  echo "OK  Vault :8200 health"
else
  for _ in 1 2 3 4 5 6; do
    sleep 2
    curl -sf "http://localhost:8200/v1/sys/health" >/dev/null && break
  done
  if curl -sf "http://localhost:8200/v1/sys/health" >/dev/null; then
    echo "OK  Vault :8200 health (after retry)"
  else
    echo "FAIL Vault :8200" >&2
    exit 1
  fi
fi

"$ROOT/lab/vault/seed-cxr-secrets.sh"

out="$(docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN=cxr-bootcamp-root \
  cxr-ops-lab-vault-1 vault kv get -field=CXR_ANALYZER_SCRIPT secret/cxr/analyzer 2>&1)" || {
  echo "FAIL read secret/cxr/analyzer" >&2
  exit 1
}

if [[ "$out" == *"/analyzers/analyze_sample.py"* ]]; then
  echo "OK  secret/cxr/analyzer CXR_ANALYZER_SCRIPT=$out"
else
  echo "FAIL unexpected analyzer secret: $out" >&2
  exit 1
fi

echo ""
echo "Browser: http://localhost:8200 → sign in token cxr-bootcamp-root → secret/cxr/analyzer"
