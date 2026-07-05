# CXR gRPC Lab Manual (SW.16)

**PDF:** `docs/manuals/grpc/manual.pdf` — `./scripts/build-grpc-manual-pdf.sh`  
**Syllabus:** SW.16 — internal RPC sketch (`Analyze(Claim)`) + grpcui  
**Date:** 2026-05-31

## What this lab adds

Minimal **gRPC** `ClaimAnalysis` service — not wired to Claim Studio **:3000** (REST + `spawn` unchanged).

| URL / port | Role |
|------------|------|
| **localhost:50051** | gRPC **ClaimAnalysis** (GetClaimStatus, AnalyzeClaim) |
| **http://localhost:8090** | **grpcui** — browser invoke / proto explorer |

## Quick start

```bash
cd cxr-ops-lab
./scripts/19-grpc-up.sh
./scripts/19-grpc-smoke.sh
```

Open **http://localhost:8090** → select **cxr.v1.ClaimAnalysis** → **AnalyzeClaim** → paste JSON from `lab/grpc/request-golden.json`.

## Golden path (RPC)

**GetClaimStatus**

```json
{ "claim_id": "demo-1" }
```

Expected: `status: "ok"`, summary matches GraphQL/Kafka fixture.

**AnalyzeClaim**

```json
{ "claim_id": "demo-1", "content": "SW.16 golden-path fixture" }
```

Expected: `status: "ok"`, `latency_ms` populated.

## Where gRPC would sit in CXR

```
Browser :3000  →  Next.js BFF (REST today)
                      ↓  (hypothetical)
                 gRPC client  →  :50051 ClaimAnalysis  →  Python analysis kernel
```

Production sandbox reference (read-only): kernel API **:8281** — different stack, same *placement* idea (internal RPC behind gateway).

## Files

| Path | Role |
|------|------|
| `lab/grpc/cxr_claim.proto` | Service + messages |
| `lab/grpc/server.mjs` | gRPC server |
| `lab/grpc/client-smoke.mjs` | Smoke client (used in healthcheck + script) |
| `lab/grpc/request-golden.json` | grpcui request body |
| `compose.grpc.yaml` | Server + grpcui |
| `scripts/19-grpc-up.sh` / `19-grpc-smoke.sh` | Start + verify |
| `evidence/SW16-grpc-verify-2026-05-31.md` | Checklist |

## Stop

```bash
docker compose -f compose.grpc.yaml down
```

## UI evidence — grpcui (:8090)

Screenshot: `evidence/SW16-grpcui-2026-05-31.png` — **AnalyzeClaim** request form.

Golden invoke:

| Field | Value |
|-------|--------|
| `claim_id` | `demo-1` |
| `content` | `SW.16 golden-path fixture` |

Expected Response: `status: "ok"`, `summary` matches GraphQL/Kafka fixture.

## Live fix (reflection)

grpcui requires **gRPC server reflection**. Without `@grpc/reflection` on `server.mjs`, grpc-ui crash-loops with *"server does not support the reflection API"*. After adding reflection, restart grpc-ui if it was created before the fix.

## After SW.16

**SW.17 Vault** — `./scripts/20-vault-up.sh` → **:8200**  
**SW.18 Langfuse** — `./scripts/21-langfuse-up.sh` → **:3100**
