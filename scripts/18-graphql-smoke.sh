#!/usr/bin/env bash
# SW.15 — Health check + golden federated query.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

for port in 4001 4002; do
  if curl -sf -H "Content-Type: application/json" \
    -d '{"query":"{ __typename }"}' "http://localhost:${port}/graphql" >/dev/null; then
    echo "OK  subgraph :${port}"
  else
    echo "FAIL subgraph :${port}" >&2
    exit 1
  fi
done

body="$(curl -sf -H "Content-Type: application/json" \
  -d '{"query":"query { claim(id: \"demo-1\") { id status summary } policyForClaim(claimId: \"demo-1\") { code } }"}' \
  "http://localhost:4000/graphql")" || {
  echo "FAIL gateway :4000" >&2
  exit 1
}

if echo "$body" | grep -q '"status":"ok"' && echo "$body" | grep -q 'CXR-POL-OK'; then
  echo "OK  gateway federated query (claim + policy)"
  echo "$body" | head -c 400
  echo ""
else
  echo "FAIL unexpected gateway response:" >&2
  echo "$body" >&2
  exit 1
fi

echo ""
echo "Browser: http://localhost:4000/graphql → paste lab/graphql/query-golden.graphql"
