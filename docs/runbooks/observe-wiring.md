# Observe stack — wiring (SW.9–11)

| File | Role |
|------|------|
| **`compose.observe.yaml`** | Docker Compose — Prometheus, Grafana, **Jaeger**, **otel-collector** |
| **`observe/prometheus.yml`** | Prometheus scrape config |
| **`observe/otel-collector-config.yaml`** | Collector receives OTLP, exports to Jaeger |
| **`observe/grafana/provisioning/`** | Grafana datasources + dashboards |

## URLs

| URL | Service |
|-----|---------|
| http://localhost:9090 | Prometheus |
| http://localhost:3001 | Grafana |
| http://localhost:16686 | **Jaeger UI (traces)** |
| http://localhost:4318 | **OTel Collector OTLP HTTP** |

## SW.11 instrumentation

- **App:** `cxr-ui-prune-rehearsal/cxr-ui/instrumentation.ts`
- **Enable:** set `OTEL_EXPORTER_OTLP_ENDPOINT` (see `.env.otel.example`)
- **Rehearsal :8251:** `http://127.0.0.1:4318`
- **Compose :3000:** `compose.otel-link.yaml` + rebuild `cxr-ui:compose`

## Commands

```bash
./scripts/07-observe-up.sh
./scripts/11-otel-smoke.sh
```

Manual: `docs/CXR-OTEL-LAB-MANUAL.pdf` (`./scripts/build-otel-manual-pdf.sh`).

## Connection to rehearsal

- **Not** in `cxr-ui-rehearsal` GitHub CI.
- Prometheus still scrapes compose :3000 when configured in `prometheus.yml`.
- Traces require OTel env on the running Next.js process.

## SW.12 logs (ELK — separate compose)

| URL | Service |
|-----|---------|
| http://localhost:9200 | Elasticsearch |
| http://localhost:5601 | **Kibana UI (logs)** |

```bash
./scripts/16-elk-up.sh
./scripts/16-elk-smoke.sh
```

Manual: `docs/CXR-ELK-LAB-MANUAL.pdf` (`./scripts/build-elk-manual-pdf.sh`) · Evidence: `evidence/SW12-elk-verify-2026-05-29.md`

## Live Operations Center (synthetic readiness)

| URL | Role |
|-----|------|
| http://localhost:8251/live-ops | CXR site embed (Grafana solo panels) |
| http://localhost:3001/d/cxr-live-ops/cxr-live-operations-center | Full **CXR Live Operations Center** dashboard |
| http://localhost:9103/metrics | Synthetic `synthetic_*` metrics exporter |

```bash
./scripts/25-synthetic-readiness-up.sh start   # after :8251 + :8766 up
docker compose -f compose.observe.yaml restart prometheus
docker compose -f compose.observe.yaml up -d --force-recreate grafana  # embed env (not restart-only)
```

Runbook: [docs/operations/live-operations-center.md](operations/live-operations-center.md)

## Persistence

- Volumes: `grafana_data`, `prometheus_data`, `elk_es_data`
- systemd: `cxr-observe.service` via `09-enable-persistent-ports.sh`
