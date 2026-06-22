# GATE-001 — Automated LOAD regression gate

Headless Locust stages with CSV scoring — replaces manual Grafana babysitting for **pass/fail** on deploys.

## Quick start

```bash
export PATH="$HOME/staging/cxr-ops-lab/bin:$PATH"
kubectl config use-context docker-desktop

# Observe + exporter (Prometheus recording rules)
./scripts/23-k8-load-observe-up.sh

# Stack + KEDA + VPA + Helm (feature branch)
./scripts/06-helm-install-stack.sh

# Gate (default: 50 → 100 → 150 → 200 users, 3m each)
./scripts/k8-load-gate.sh

# 200-user stage report-only (known knee on Docker Desktop)
./scripts/k8-load-gate.sh --soft-200
```

Reports: `/tmp/cxr-load-gate/gate-report-*.json`

## What it checks (per stage)

| Signal | Default threshold |
|--------|-------------------|
| Replica collapses (≥5 → ≤2) | **0** |
| `failures/s` peak | **≤ 0.5** |
| Locust `p95` | 50→2s, 100→3s, 150→4.5s, 200→6s |
| Users reached | ≥ 85% of target |

Override: `CXR_GATE_MAX_COLLAPSES`, `CXR_GATE_MAX_FAILURES`, `CXR_GATE_STAGE_TIME`, `CXR_GATE_STAGES`.

## Prometheus recording rules

File: `observe/prometheus/cxr_recording_rules.yml`

| Rule | Meaning |
|------|---------|
| `cxr_load_stable` | 1 when failures, pending, p95 within bounds |
| `cxr_replica_collapse` | 1 when analyzer replicas cliff-drop |
| `cxr_load_p95_pressure` | alias of `cxr_locust_p95_ms` for KEDA |

Query in Prometheus: http://127.0.0.1:9090/graph

## Phase B — KEDA (runtime scaling)

- **Script:** `scripts/11-keda-install.sh`
- **Helm:** `autoscaling.keda.enabled: true` on `cxr-analyzer` (replaces CPU-only HPA)
- **Triggers:** CPU 70% + Prometheus `cxr_locust_p95_ms` > 2000ms (when load exporter running)
- **`minReplicas: 2`** — warm pool to reduce 8→1 cliffs

Disable KEDA (CPU HPA only): `autoscaling.keda.enabled: false`

## Phase C — VPA + Pyroscope

**VPA (recommendation only)**

```bash
./scripts/12-vpa-install.sh
kubectl describe vpa cxr-analyzer -n cxr-ui   # after load
```

Helm: `autoscaling.vpa.enabled: true`, `updateMode: "Off"`

**Pyroscope (optional profiling)**

```bash
./scripts/24-pyroscope-up.sh up    # http://127.0.0.1:4040
```

Does not auto-tune parameters — use for code hotspots (PERF-004).

## GitOps / Argo

Push `helm/cxr-analyzer/values.yaml` to `main`. Until merged, **suspend Argo auto-sync** when applying KEDA locally (Argo on `main` still deploys CPU-only HPA and blocks ScaledObject):

```bash
kubectl patch application cxr-analyzer -n argocd --type merge -p '{"spec":{"syncPolicy":{"automated": null}}}'
kubectl delete hpa cxr-analyzer -n cxr-ui --ignore-not-found
./scripts/06-helm-install-stack.sh
```

Argo parameters (when sync re-enabled):

```bash
kubectl patch application cxr-analyzer -n argocd --type merge -p '{
  "spec": {"source": {"helm": {"parameters": [
    {"name": "image.tag", "value": "perf003", "forceString": true},
    {"name": "autoscaling.maxReplicas", "value": "8"},
    {"name": "autoscaling.minReplicas", "value": "2"},
    {"name": "autoscaling.keda.enabled", "value": "true"}
  ]}}}}'
```

## CI

`.github/workflows/k8-load-gate.yml` — `workflow_dispatch` for **self-hosted** runners with Docker Desktop K8. GitHub-hosted runners cannot run this gate.

## Revert branch

```bash
cd ~/staging/cxr-ops-lab && git checkout main
cd ~/staging/cxr-portfolio && git checkout master
```

Or stay on `feature/load-perf-automation` until gate passes.
