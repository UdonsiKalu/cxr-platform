# CXR OpenTelemetry Lab Manual (SW.11)

**PDF:** `./scripts/build-otel-manual-pdf.sh` → `docs/manuals/otel/manual.pdf`  
**Syllabus:** Starter milestone **#7**, **SW.11**, ties **M1.6**  
**Date:** 2026-05-31 (updated — :8251 ↔ Jaeger connection)

---

## What this lab adds

You already have **metrics** (Prometheus + Grafana, SW.9–10). **OpenTelemetry** adds **distributed traces**: one timeline per HTTP request (e.g. Claim Studio `analyze`).

| Signal | Tool | URL | Has a web UI? |
|--------|------|-----|----------------|
| Metrics | Prometheus | http://localhost:9090 | Yes (query UI) |
| Dashboards | Grafana | http://localhost:3001 | Yes |
| **Traces** | **Jaeger** | **http://localhost:16686** | **Yes — this is where you view traces** |
| OTLP ingest | OTel Collector | http://localhost:4318 | **No** — background pipe only |

---

## How :8251 rehearsal connects to Jaeger (read this first)

This is the wiring you proved when **Run Analysis** on Claim Studio made traces appear in Jaeger **immediately**.

### End-to-end path

```
You (browser)  http://localhost:8251/claim-studio
    → Click "Run Analysis"
    → POST /api/claim-studio/analyze

cxr-ui-rehearsal (Next.js on host :8251)
    → instrumentation.ts runs at process start (only if OTEL_* env set)
    → HTTP auto-instrumentation wraps the POST → creates spans
    → OTLP HTTP export POST http://127.0.0.1:4318/v1/traces

otel-collector (Docker, no UI)
    → receives OTLP, batches, forwards

Jaeger (Docker)
    → stores trace

Jaeger UI  http://localhost:16686
    → Search → Service "cxr-ui-rehearsal" → you see the POST trace (often within seconds)
```

### What actually “connects” the app to Jaeger

| Layer | What you configure | What it does |
|--------|-------------------|--------------|
| **1. Observe stack** | `./scripts/07-observe-up.sh` | Starts **collector** + **Jaeger** on Docker network `cxr_observe` |
| **2. Env on :8251** | `OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:4318` and `OTEL_SERVICE_NAME=cxr-ui-rehearsal` | Tells the Next.js process **where to send** traces and **what name** Jaeger shows |
| **3. Start order** | Export env **before** `npm run dev:rehearsal` | `instrumentation.ts` `register()` runs once at startup; no endpoint → no export |
| **4. App code** | `cxr-ui-prune-rehearsal/cxr-ui/instrumentation.ts` → `instrumentation/register-otel-node.ts` | NodeSDK + OTLP exporter + HTTP auto-instrumentation |
| **5. User action** | **Run Analysis** | One **POST** = one new trace in Jaeger (plus separate **GET** traces for page loads) |

### Important: systemd vs manual dev

Daily **`cxr-rehearsal-dev`** systemd service on **:8251** does **not** set `OTEL_*`. For this lab:

```bash
systemctl --user stop cxr-rehearsal-dev
export OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:4318
export OTEL_SERVICE_NAME=cxr-ui-rehearsal
cd cxr-ui-prune-rehearsal/cxr-ui
npm run dev:rehearsal
```

When finished, `systemctl --user start cxr-rehearsal-dev` for normal dev without tracing.

### Why Run Analysis “popped up” in Jaeger right away

1. Browser sends **POST** to your Next API route.
2. OTel HTTP instrumentation records spans on the **Node** server (same process as `:8251`).
3. Exporter sends spans to **:4318** (not to Jaeger directly — collector is in the middle).
4. Jaeger UI polls/search index — new trace visible after export (typically seconds).

In the waterfall you should see something like:

- `POST /api/claim-studio/analyze`
- child span **`executing api route`** (~seconds) — Node waiting on analyze handler (Python subprocess is **not** a separate span in this lab)

### GET vs POST in Jaeger

| Method | When | Duration (typical) |
|--------|------|---------------------|
| **GET** | Opening pages, navigation | ms – ~2s |
| **POST** | **Run Analysis** | ~5–11s (analyzer work) |

Jaeger lists **one trace per HTTP request** — not one trace for your whole session.

### Collector has no dashboard

- **:4318** in the browser → **404 on `/`** is normal (OTLP ingest API only).
- **:16686** is the only trace UI in this lab.

---

## Architecture (components)

```
Browser
    → cxr-ui-rehearsal :8251 (instrumentation + HTTP spans)
    → OTLP HTTP :4318/v1/traces
    → otel-collector (background)
    → Jaeger
    → Jaeger UI :16686
```

---

## Files added or changed

| Path | Role |
|------|------|
| `compose/observe/compose.yaml` | + `jaeger`, `otel-collector`, network `cxr_observe` |
| `observe/otel-collector-config.yaml` | Collector: OTLP in → Jaeger out |
| `.env.otel.example` | Env vars for :8251 / :3000 |
| `compose/observe/otel-link.yaml` | Optional: compose UI → collector on Docker network |
| `scripts/07-observe-up.sh` | Start full observe + OTel stack |
| `scripts/11-otel-smoke.sh` | Health check |
| `instrumentation.ts` | Next.js hook; dynamic import of node-only SDK |
| `instrumentation/register-otel-node.ts` | NodeSDK, OTLP exporter, `process.on` shutdown |
| `next.config.ts` | `serverExternalPackages` for OTel (fixes resolve errors) |
| `evidence/SW11-otel-verify-2026-05-29.md` | Evidence template |
| `evidence/SW11-jaeger-search-*.png` | Example search screenshot |
| `evidence/SW11-jaeger-waterfall-post-analyze-*.png` | Example POST waterfall |

---

## Step 1 — Start the observe stack

```bash
cd /path/to/cxr-ops-lab
./scripts/07-observe-up.sh
./scripts/11-otel-smoke.sh
```

Confirm Jaeger UI loads at http://localhost:16686.

---

## Step 2 — Install app dependencies (once)

```bash
cd ../cxr-ui-prune-rehearsal/cxr-ui
npm install
```

---

## Step 3 — Wire :8251 to the collector (env + dev server)

```bash
systemctl --user stop cxr-rehearsal-dev   # if enabled — avoids port conflict / missing OTEL
export OTEL_EXPORTER_OTLP_ENDPOINT=http://127.0.0.1:4318
export OTEL_SERVICE_NAME=cxr-ui-rehearsal
npm run dev:rehearsal
```

Copy env from `cxr-ops-lab/.env.otel.example`.

---

## Step 4 — Golden path: Run Analysis → Jaeger

1. Open http://localhost:8251/claim-studio  
2. Click **Run Analysis**  
3. Wait for analyze **200**  
4. Open http://localhost:16686 → **Search** → Service **`cxr-ui-rehearsal`** → **Find Traces**  
5. Open the newest **POST** trace (~5–11s) → Timeline / waterfall screenshot  

You have connected :8251 to Jaeger when this POST appears right after Run Analysis.

---

## Step 5 — Document (syllabus evidence)

Edit `cxr-ops-lab/evidence/SW11-otel-verify-2026-05-29.md`:

- Connection summary (:8251 + `OTEL_*` → :4318 → Jaeger)  
- Where spans start (`instrumentation.ts`, HTTP auto-instrumentation)  
- What is **not** traced yet (Python `spawn` subprocess)  
- Attach Jaeger search + POST waterfall screenshots  

---

## Implementing this yourself (checklist)

Use this when you repeat SW.11 on another machine or productize tracing:

- [ ] Observe compose up (collector + Jaeger)  
- [ ] `OTEL_EXPORTER_OTLP_ENDPOINT` points at collector OTLP HTTP (**host** `127.0.0.1:4318` for host-run Next)  
- [ ] `OTEL_SERVICE_NAME` set (appears in Jaeger service dropdown)  
- [ ] Next `instrumentation.ts` + Node SDK registered before traffic  
- [ ] Env set **before** `next dev` / container start  
- [ ] Generate traffic (**Run Analysis** = POST trace)  
- [ ] Confirm in **Jaeger UI only** (not :4318)  

---

## Optional — Compose :3000

Requires **rebuild** `cxr-ui:compose` after `npm install` + instrumentation in build context:

```bash
cd cxr-ops-lab
./scripts/07-observe-up.sh
./scripts/04-compose-up.sh
docker compose -f compose/core/compose.yaml -f compose/core/host.yaml -f compose/observe/otel-link.yaml up -d
```

Jaeger service name: `cxr-ui-compose`.

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| No traces in Jaeger | `OTEL_EXPORTER_OTLP_ENDPOINT` set **before** `next dev`; restart dev after env change |
| Run Analysis works but Jaeger empty | Wrong service name filter — use `cxr-ui-rehearsal` |
| Port 8251 in use | Stop systemd `cxr-rehearsal-dev` or old dev process |
| Jaeger empty service list | Send at least one request after server start |
| :4318 shows 404 in browser | Expected — not a UI |
| Collector down | `docker ps \| grep otel` ; `./scripts/07-observe-up.sh` |
| Disable OTel | `export OTEL_SDK_DISABLED=true` |

---

## Starter track status after SW.11

| # | Milestone | Status |
|---|-----------|--------|
| 7 | OpenTelemetry | **This lab** — traces verified via :8251 → Jaeger |
| 1–6, 8–10 | Earlier milestones | Done (see K8 manual + handoff) |

Next syllabus picks: **M1.1/M1.2**, **SW.12–18** electives, evidence polish.
