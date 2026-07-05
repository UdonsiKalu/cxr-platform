# K8 load test — live Grafana + Jaeger (OBS-001)

Run **after** stack verify (`16-k8-stack-verify.sh`). GitOps Helm on `feature/load-perf-automation`: `maxReplicas: 8`, `minReplicas: 2`, KEDA optional.

**Automated regression gate:** [K8-LOAD-GATE.md](./K8-LOAD-GATE.md) · `./scripts/k8-load-gate.sh`

## 1. Save / commit (before long run)

```bash
cd ~/staging/cxr-ops-lab && git status
cd ~/staging/cxr-portfolio && git status
# commit chart CSV path + screenshots when run completes
```

## 2. Start observe + K8 metrics (one terminal)

```bash
export PATH="$HOME/staging/cxr-ops-lab/bin:$PATH"
kubectl config use-context docker-desktop
cd ~/staging/cxr-ops-lab
./scripts/23-k8-load-observe-up.sh
```

Open:

| URL | Purpose |
|-----|---------|
| http://127.0.0.1:3001/d/cxr-hpa-load-003 | **Grafana** — Locust + HPA + node (live + history, refresh 5s) |
| http://127.0.0.1:9090/targets | **Prometheus** — `kube-state-metrics` must be **UP** |
| http://127.0.0.1:16686 | **Jaeger** — service `cxr-analyzer-service` |

If `kube-state-metrics` target is **DOWN**:

```bash
./scripts/k8-ksm-port-forward.sh start
docker compose -f compose.observe.yaml restart prometheus
```

## 3. Preflight stack

```bash
./scripts/16-k8-stack-verify.sh
./scripts/k8-ui-forward.sh check
```

## 4. LOAD-003 ramp — 200 users (four terminals)

**A — CSV collector (portfolio evidence, optional):**

```bash
cd ~/staging/cxr-portfolio
export PATH="$HOME/staging/cxr-ops-lab/bin:$PATH"
export CXR_LOCUST_URL=http://127.0.0.1:8092
./investigations/kubernetes-analyzer-saturation/run-k8-load-with-metrics.sh
```

**B — Locust:**

```bash
cd ~/staging/cxr-portfolio
CXR_LOAD_URL=http://127.0.0.1:8081 \
CXR_LOCUST_WEB_PORT=8092 \
CXR_RAMP_MAX_USERS=200 CXR_RAMP_START_USERS=15 CXR_RAMP_STEP_USERS=5 CXR_RAMP_STAGE_SECONDS=60 \
./investigations/analyzer-saturation/run-saturation-ramp-until-break-gui.sh
```

Start swarm in http://127.0.0.1:8092

**C — kubectl watch (optional):**

```bash
./scripts/k8-hpa-watch.sh
```

**D — Grafana** — watch panels during ramp (no wait for end plot).

## 5. Jaeger during / after load

1. Jaeger UI → Search → Service **`cxr-analyzer-service`** → Find Traces  
2. Sort by **longest duration** during a p95 spike window  
3. Export JSON:

```bash
./scripts/jaeger-k8-traces-snapshot.sh \
  ~/staging/cxr-portfolio/investigations/kubernetes-analyzer-saturation/evidence/load-observe/jaeger-traces.json
```

Compare spans: `context_builder`, `retrieval`, `llm.model_request.send`, `analyzer_service.startup`.

K8 UI traces: add `OTEL_*` to `helm/cxr-ui/values.yaml` if you need `cxr-ui-k8` service in Jaeger.

### Jaeger compare cheat sheet

Use **same service + same operation** for both traces. Copy **full 32-char trace IDs** from the URL after opening a trace (short list IDs break Compare on older Jaeger; stack uses **2.19.0**).

| Pair | Service | Operation | What you learn |
|------|---------|-----------|----------------|
| **1 — scaling** | `cxr-analyzer-service` | `analyzer_service.startup` | Cold-start cost per new pod (~15–17s) |
| **2 — requests** | `cxr-ui-k8` | `POST` | Fast vs slow; read `context_builder` duration |

**Search quirk:** filtering by `cxr-analyzer-service` returns traces that *contain* analyzer spans; the trace header may still show root `cxr-ui-k8: POST`.

**Invalid compare:** `analyzer_service.startup` vs `POST` — different jobs; overlay is misleading.

Documented run with screenshots: `cxr-portfolio/investigations/kubernetes-analyzer-saturation/evidence/load-observe/RUN-2026-06-17.md`

## 6. After run

```bash
# Plot CSV (portfolio)
cd ~/staging/cxr-portfolio/investigations/kubernetes-analyzer-saturation
.venv/bin/python plot_load_test.py results/load-*.csv -o results/charts

# Save Grafana/Jaeger screenshots → evidence/load-observe/ (see RUN-YYYY-MM-DD.md template)

# Stop observe forwards (optional)
cd ~/staging/cxr-ops-lab
./scripts/k8-ksm-port-forward.sh stop
```

## Grafana vs Locust vs Jaeger

| Signal | Tool |
|--------|------|
| Users, RPS, p50, p95, failures | **Grafana** `cxr-hpa-load-003` (via `cxr-load-exporter` → Prometheus) |
| Same live charts | **Locust** :8092 Charts (optional) |
| HPA CPU %, replicas, pending, node % | **Grafana** (same dashboard) |
| Per-request latency | **Jaeger** |
| CSV archive (optional) | `run-k8-load-with-metrics.sh` — not required for charts |
