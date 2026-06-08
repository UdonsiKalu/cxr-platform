# SW.14 — Redis verify (2026-05-31)

## Stack

| URL | Service |
|-----|---------|
| redis://localhost:6379 | **Redis** (cache) |
| http://localhost:5540 | **Redis Insight** (web UI) |

## What this lab adds (vs SW.12 / SW.11)

| Pattern | Tool | SW |
|---------|------|-----|
| Logs | Elasticsearch + Kibana | SW.12 |
| Traces | Jaeger | SW.11 |
| Async events | Kafka | SW.13 |
| **Hot read cache** | **Redis cache-aside + Redis Insight** | **SW.14** |

## Commands

```bash
./scripts/17-redis-up.sh
./scripts/17-redis-smoke.sh
./lab/redis-cache-aside.sh
```

## Cache-aside demo

- **Key:** `cxr:claim:analyzed:demo-1`
- **Source:** `lab/fixtures/claim-analyzed.demo.json` (CXR-shaped JSON; schema `schemas/cxr.claim-analyzed.v1.json`)
- **TTL:** 300s (`CXR_CACHE_TTL_SEC`)
- **Invalidation:** `redis-cli DEL cxr:claim:analyzed:demo-1` (or second `redis-cache-aside.sh` when warm)

## Not wired (bootcamp scope)

- **cxr-ui** Claim Studio does **not** call Redis yet — lab script only.
- **:8251** rehearsal dev unchanged.
- Do **not** cache live **Run Analysis** results without an invalidation story (consistency ADR in manual).

## Checklist

- [x] `./scripts/17-redis-smoke.sh` → PONG + CACHE HIT
- [x] Run `./lab/redis-cache-aside.sh` twice (second run shows warm key + DEL)
- [x] Terminal verify: `redis-cli GET cxr:claim:analyzed:demo-1` → JSON (user 2026-05-31)
- [x] Redis Insight screenshot **`evidence/SW14-redis-insight-2026-05-31.png`** — key + JSON + TTL on **:5540**
- [x] Manual PDF: **`docs/CXR-REDIS-LAB-MANUAL.pdf`** (Redis + Redis Insight full inventory)

## User verify (2026-05-31)

- Golden path: `17-redis-up` → `redis-cache-aside` ×2 → `17-redis-smoke`
- Insight connected via **`redis://redis:6379`** (not `127.0.0.1`)
- UI screenshot: `cxr:claim:analyzed:demo-1`, STRING 264 B, TTL ~243s, full claim-analyzed JSON

## Agent verify (2026-05-31)

- `./scripts/17-redis-up.sh` — `cxr-ops-lab-redis-1` + `cxr-ops-lab-redis-insight-1`
- `./scripts/17-redis-smoke.sh` — PONG + cache-aside **CACHE HIT**
- PDF rebuilt with Redis Insight chapter (~297 KB)

## Next syllabus

**SW.15 GraphQL** lab.
