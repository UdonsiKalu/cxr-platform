# CXR Redis Lab Manual (SW.14)

**PDF:** `docs/CXR-REDIS-LAB-MANUAL.pdf` — build: `./scripts/build-redis-manual-pdf.sh`  
**Syllabus:** SW.14 — Redis cache-aside + Redis Insight UI  
**Date:** 2026-05-31 (Redis Insight baked in)

## What this lab adds

| Pattern | Tool | URL | SW |
|---------|------|-----|-----|
| Hot read cache | **Redis** | redis://localhost:**6379** | SW.14 |
| Cache browser UI | **Redis Insight** | http://localhost:**5540** | SW.14 |

Cache-aside: `GET` → miss → load JSON fixture → `SETEX` → `GET` hit → `DEL` on invalidation.

**Claim Studio (:3000)** is the product dashboard — **not wired to Redis** in this lab (script-only).

## Architecture

```
lab/fixtures/claim-analyzed.demo.json
  → lab/redis-cache-aside.sh
  → Redis :6379 (key cxr:claim:analyzed:demo-1)
  → Redis Insight :5540 (browse key + TTL)
```

## Quick start

```bash
cd cxr-ops-lab
./scripts/17-redis-up.sh
./lab/redis-cache-aside.sh
./scripts/17-redis-smoke.sh
```

## Redis Insight (web UI)

1. **Simple Browser** → `http://localhost:5540`
2. **Add database** — URL: `redis://redis:6379` (NOT `127.0.0.1`)
3. Run `./lab/redis-cache-aside.sh` once
4. Refresh → click `cxr:claim:analyzed:demo-1` → JSON + TTL
5. Screenshot → `evidence/SW14-redis-insight-2026-05-31.png`

**Tips:** Second script run DELs warm key. Use `CXR_CACHE_TTL_SEC=3600` for long screenshots. Skip “Load sample data”.

## Files (full inventory)

| Path | Role |
|------|------|
| `compose.redis.yaml` | Redis 7.4 + Redis Insight 2.70 |
| `lab/redis-cache-aside.sh` | Cache-aside demo |
| `lab/fixtures/claim-analyzed.demo.json` | Cached payload |
| `schemas/cxr.claim-analyzed.v1.json` | Event schema (Kafka + cache) |
| `scripts/17-redis-up.sh` | Start stack |
| `scripts/17-redis-smoke.sh` | PING + Insight + cache-aside |
| `scripts/build-redis-manual-pdf.sh` | Build PDF |
| `docs/CXR-REDIS-LAB-MANUAL.{md,tex,pdf}` | This manual |
| `docs/diagrams/06-redis-cache-aside.mmd` | Sequence diagram |
| `evidence/SW14-redis-verify-2026-05-31.md` | Checklist |
| `evidence/SW14-redis-insight-2026-05-31.png` | UI evidence |

## Troubleshooting

| Issue | Fix |
|-------|-----|
| :6379 in browser | No HTTP UI — use :5540 or redis-cli |
| Insight can't connect to 127.0.0.1 | Host `redis` or `redis://redis:6379` |
| Key listed but “does not exist” | TTL expired or DEL — re-run cache-aside, refresh |
| Empty db0 | Same — one `./lab/redis-cache-aside.sh`, refresh |

## Stop

```bash
docker compose -f compose.redis.yaml down
```

## After SW.14

**SW.15 GraphQL** lab.
