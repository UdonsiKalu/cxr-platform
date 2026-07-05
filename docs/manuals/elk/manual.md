# CXR ELK Lab Manual (SW.12)

**PDF:** `docs/CXR-ELK-LAB-MANUAL.pdf` — build: `./scripts/build-elk-manual-pdf.sh`  
**Syllabus:** SW.12 — logs (Elasticsearch + Kibana + Filebeat)  
**Date:** 2026-05-31

## What ELK is (in this lab)

| Signal | Tool | URL | SW |
|--------|------|-----|-----|
| Metrics | Prometheus / Grafana | :9090 / **:3001** | SW.9–10 |
| Traces | Jaeger | **:16686** | SW.11 |
| **Logs** | **Elasticsearch + Kibana + Filebeat** | **:9200 / :5601** | **SW.12** |

**Claim Studio (main CXR dashboard):** http://localhost:3000/claim-studio — generates **Docker logs** from the `cxr-ui` container.  
**Kibana** is a **separate** UI for searching those logs — not embedded in the app.

## How :3000 connects to Kibana

```
Browser /claim-studio (:3000)
  → cxr-ui container stdout/stderr
  → Filebeat (reads Docker logs via socket)
  → Elasticsearch (:9200, index filebeat-*)
  → Kibana Discover (:5601)
```

**Wiring:**

1. `compose.yaml` — `cxr-ui` service label `cxr.bootcamp.logs: "true"` + container name `cxr-ui`
2. `observe/elk/filebeat.yml` — autodiscover matches that container
3. `compose.elk.yaml` — ES + Kibana + Filebeat stack

**Not wired:** rehearsal **:8251** host `npm` dev (logs stay in terminal unless you add another Filebeat input).

**Jaeger vs ELK:** Jaeger = request traces/latency (SW.11). Elasticsearch = log lines/errors. Fair to stop ELK after SW.12 evidence; keep Jaeger for :8251 work.

## Quick start

```bash
cd cxr-ops-lab
./scripts/04-compose-up.sh    # if :3000 not up
./scripts/16-elk-up.sh
./scripts/16-elk-smoke.sh
./scripts/build-elk-manual-pdf.sh   # optional PDF
```

Open **http://localhost:5601** (Kibana).

## Golden path (Claim Studio → logs)

1. http://localhost:3000/claim-studio  
2. Run Analysis (or reload pages)  
3. Wait ~30s for Filebeat to index  
4. Kibana → **Explore on my own** → **Stack Management → Data Views** → `filebeat-*` (`@timestamp`)  
5. **Discover** → time range **Last 24 hours** → refresh  
6. Screenshot → `evidence/SW12-kibana-discover-*.png`  
7. Update `evidence/SW12-elk-verify-2026-05-29.md`

### Kibana tips

- Ignore Security sidebar on Home; skip Add integrations  
- No undo ↩ arrow? Click **time range** → Last 24 hours → Update + refresh  
- Optional KQL: `claim-studio` or `analyze`

## Files created (SW.12)

| Path | Role |
|------|------|
| `compose.elk.yaml` | ES :9200, Kibana :5601, Filebeat |
| `observe/elk/filebeat.yml` | Docker autodiscover → cxr-ui |
| `scripts/16-elk-up.sh` | Start stack |
| `scripts/16-elk-smoke.sh` | Health + index check |
| `scripts/build-elk-manual-pdf.sh` | Build PDF |
| `docs/CXR-ELK-LAB-MANUAL.md` / `.tex` / `.pdf` | This manual |
| `evidence/SW12-elk-verify-2026-05-29.md` | Verify checklist |

**Touched:** `compose.yaml` (label), `docs/OBSERVE-WIRING.md`, `docs/PLATFORM-SYLLABUS-MAP.md`

## Port map (relevant)

| Port | Service |
|------|---------|
| **3000** | Claim Studio (log **source**) |
| **5601** | Kibana (log **UI**) |
| 9200 | Elasticsearch API |
| 8251 | Rehearsal dev (OTel traces, not default logs) |
| 16686 | Jaeger (traces) |
| 3001 | Grafana (metrics) |

## Stop

```bash
docker compose -f compose.elk.yaml down
```

## After SW.12

Syllabus next: **SW.14 Redis**. See also `docs/CXR-OTEL-LAB-MANUAL.pdf` (SW.11 traces).
