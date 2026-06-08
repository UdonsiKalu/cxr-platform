# SW.11 — OpenTelemetry verify (2026-05-29)

## Stack

| URL | Service |
|-----|---------|
| http://localhost:4318 | OTel Collector (OTLP HTTP) |
| http://localhost:16686 | Jaeger UI |
| http://localhost:9090 | Prometheus |
| http://localhost:3001 | Grafana |

## Instrumentation

- **File:** `cxr-ui-prune-rehearsal/cxr-ui/instrumentation.ts`
- **Active when:** `OTEL_EXPORTER_OTLP_ENDPOINT` is set
- **Service names:** `cxr-ui-rehearsal` (:8251) or `cxr-ui-compose` (:3000)

## Golden path traced

1. Browser → Claim Studio **Run Analysis** on **:8251** with `OTEL_EXPORTER_OTLP_ENDPOINT` set
2. Jaeger Search → Service **`cxr-ui-rehearsal`** → **9 traces** (2026-05-30 ~22:15–22:20 local)
3. **POST** traces **~5.65s** and **~11s** (5 spans each) = analyze/API work; **GET** traces under **2s** (1–9 spans) = page/navigation
4. Waterfall **POST `/api/claim-studio/analyze`** (11s trace): `resolve page components` ~77ms → **`executing api route`** ~10.6s → `start response` ~302µs (Python subprocess not traced)

## Jaeger screenshot

- [x] Search scatter plot: `evidence/SW11-jaeger-search-2026-05-30.png` (9 traces, service `cxr-ui-rehearsal`)
- [x] POST waterfall: `evidence/SW11-jaeger-waterfall-post-analyze-2026-05-30.png` (`POST aaeb8c8`, 5 spans, 11s)

## Where spans start

- Next.js Node server runtime (`instrumentation.ts` → `register()` on process start)
- HTTP instrumentation wraps incoming `POST /api/claim-studio/analyze`

## Not instrumented (bootcamp scope)

- Python `analyze_sample.py` subprocess (separate process; would need Python OTel SDK)
