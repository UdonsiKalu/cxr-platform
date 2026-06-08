#!/usr/bin/env bash
# Seed CXR-shaped secrets into Vault dev KV v2 (run via 20-vault-smoke.sh or manually).
set -euo pipefail

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-cxr-bootcamp-root}"
CONTAINER="${VAULT_CONTAINER:-cxr-ops-lab-vault-1}"

vault_exec() {
  docker exec -e VAULT_ADDR=http://127.0.0.1:8200 -e VAULT_TOKEN="$VAULT_TOKEN" \
    "$CONTAINER" vault "$@"
}

echo "Enabling KV v2 at secret/ (idempotent)..."
vault_exec secrets enable -path=secret kv-v2 2>/dev/null || true

echo "Writing secret/cxr/analyzer ..."
vault_exec kv put secret/cxr/analyzer \
  CXR_ANALYZER_SCRIPT="/analyzers/analyze_sample.py" \
  CXR_JUDGE_SCRIPT="/analyzers/judge_claim.py"

echo "Writing secret/cxr/otel ..."
vault_exec kv put secret/cxr/otel \
  OTEL_EXPORTER_OTLP_ENDPOINT="http://127.0.0.1:4318" \
  OTEL_SERVICE_NAME="cxr-ui-rehearsal"

echo "Writing secret/cxr/datastores ..."
vault_exec kv put secret/cxr/datastores \
  QDRANT_URL="http://host.docker.internal:6333" \
  DATABASE_URL="placeholder-not-in-git"

echo "OK  seeded secret/cxr/{analyzer,otel,datastores}"
