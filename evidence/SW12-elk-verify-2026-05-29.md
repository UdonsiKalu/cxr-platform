# SW.12 — ELK verify (2026-05-29)

## Stack

| URL | Service |
|-----|---------|
| http://localhost:9200 | Elasticsearch API |
| http://localhost:5601 | **Kibana UI (logs)** |

## What this lab adds (vs SW.11)

| Signal | Tool | SW |
|--------|------|-----|
| Metrics | Prometheus / Grafana | SW.9–10 |
| Traces | Jaeger | SW.11 |
| **Logs** | **Elasticsearch + Kibana + Filebeat** | **SW.12** |

## Commands

```bash
./scripts/16-elk-up.sh
./scripts/16-elk-smoke.sh
```

## Log source

- **File:** `observe/elk/filebeat.yml`
- **Target:** Docker container name contains **`cxr-ui`** (Compose **:3000**)
- **Not wired:** rehearsal **:8251** host `npm` dev (unless you add a separate filebeat input later)

## Kibana saved search

- [x] Data view: **`filebeat-*`** (user data view **new CXR**)
- [x] Discover: Filebeat fields + **`cxr-ui`** container logs (6+ docs in session)
- [x] Screenshot: **`evidence/SW12-kibana-discover-2026-05-31.png`**

## Golden path

1. `./scripts/04-compose-up.sh` (or confirm **:3000** up)
2. `./scripts/16-elk-up.sh`
3. Browser → http://localhost:3000/claim-studio → Run Analysis
4. Kibana → Discover → confirm log lines appear

## User verify (2026-05-31)

- Kibana **Explore on my own** → **Stack Management → Data Views** → **Discover**
- Data view **new CXR** / pattern **`filebeat-*`**; time range widened via picker (not histogram brush)
- Discover screenshot archived (May 30 session capture)

## Agent verify (2026-05-31)

- Stack running: elasticsearch, kibana, filebeat
- Index **`.ds-filebeat-8.15.3-2026.05.31-000001`** with docs; **:3000** `cxr-ui` up
- **`16-elk-smoke.sh`** OK (2026-05-31 closeout)
- Manual PDF: **`docs/CXR-ELK-LAB-MANUAL.pdf`**

## Next syllabus

**SW.15 GraphQL** (SW.12 + SW.14 closed).
