# CXR GraphQL Lab Manual (SW.15)

**PDF:** `docs/CXR-GRAPHQL-LAB-MANUAL.pdf` — `./scripts/build-graphql-manual-pdf.sh`  
**Syllabus:** SW.15 — Apollo Gateway + two mock subgraphs  
**Date:** 2026-05-31

## What this lab adds

Minimal **GraphQL federation** — not wired to Claim Studio **:3000** (REST spine unchanged).

| URL | Role |
|-----|------|
| http://localhost:4000/graphql | **Gateway** + Apollo Sandbox UI |
| http://localhost:4001/graphql | **Claims** subgraph — `Claim { id, status, summary }` |
| http://localhost:4002/graphql | **Policies** subgraph — `Policy`, `policyForClaim` |

## Quick start

```bash
cd cxr-ops-lab
./scripts/18-graphql-up.sh
./scripts/18-graphql-smoke.sh
```

Open **http://localhost:4000/graphql** in Simple Browser; run `lab/graphql/query-golden.graphql`.

## Golden query

```graphql
query Sw15GoldenPath {
  claim(id: "demo-1") { id status summary }
  policyForClaim(claimId: "demo-1") { code description }
}
```

## Files

| Path | Role |
|------|------|
| `compose.graphql.yaml` | Gateway + 2 subgraphs |
| `lab/graphql/claims-subgraph.mjs` | CXR Claim type |
| `lab/graphql/policies-subgraph.mjs` | Mock policies |
| `lab/graphql/gateway.mjs` | Apollo Gateway |
| `lab/graphql/schema.graphql` | Composed schema reference |
| `lab/graphql/query-golden.graphql` | Golden path query |
| `scripts/18-graphql-up.sh` / `18-graphql-smoke.sh` | Start + verify |
| `evidence/SW15-graphql-verify-2026-05-31.md` | Checklist |

## Stop

```bash
docker compose -f compose.graphql.yaml down
```

## After SW.15

**SW.16 gRPC** — `compose.grpc.yaml` + `./scripts/19-grpc-up.sh` → grpcui **:8090**.
