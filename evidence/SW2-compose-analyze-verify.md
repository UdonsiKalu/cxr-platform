# SW.2 — Compose analyze verify (:3000)

**Date:** 2026-05-25

## Request

```http
POST http://localhost:3000/api/claim-studio/analyze
Content-Type: application/json

{"input":{"content":"{\"claim_id\":\"test-1\",\"description\":\"office visit\"}"}}
```

## Result (2026-05-26 — host network + ODBC image)

| Check | Outcome |
|-------|---------|
| HTTP status | **200** (`POST /api/claim-studio/analyze`) |
| Route reached | Yes — Next handler ran |
| `spawn python3` | Yes — `/analyzers/analyze_sample.py` |
| Host wiring | **`compose.host.yaml`** (`network_mode: host`) so Python sees **127.0.0.1:1433** SQL + **:6333** Qdrant |
| Image | **`Dockerfile.compose`** adds **msodbcsql17** + `pyodbc` + `qdrant-client` |

Earlier **500** causes (fixed in lab): missing `pyodbc`; ODBC driver missing; bridge network could not reach host SQL.

## F12 (browser)

1. Rebuild/restart: `./scripts/04-compose-up.sh` (Linux applies `compose.host.yaml` automatically)  
2. Open http://localhost:3000/claim-studio  
3. Run analysis → Network → **`analyze`** → **200**, Response has `ok: true`  
4. Proof of host mount: container logs show `/analyzers/...`; proof of host SQL/Qdrant: analyze succeeds only with host network + SQL on **:1433**

## If 500 again

`docker compose -f compose.yaml -f compose.host.yaml logs cxr-ui` — SQL down, wrong port, or not on Linux host overlay.
