# GitOps phased demo — run together on Docker Desktop K8

Walk through each phase in order. Each phase has **verify** steps before moving on.

**Prerequisites:** `kubectl config use-context docker-desktop`, `cxr-ops-lab` cloned, analyzer built locally (`./scripts/02-build-analyzer-docker-only.sh`).

---

## Phase 0 — LOAD-003 evidence (portfolio, no cluster)

**Goal:** Confirm saturation study is documented.

```bash
ls ~/staging/cxr-portfolio/investigations/kubernetes-analyzer-saturation/results/load-20260608-125236.csv
ls ~/staging/cxr-portfolio/investigations/kubernetes-analyzer-saturation/evidence/load-003/run-summary.md
```

---

## Phase 1 — K8 stack healthy (manual bootstrap once)

**Goal:** Images + namespace exist before Argo takes over.

```bash
cd ~/staging/cxr-ops-lab
./scripts/03-k8-desktop-stack-up.sh    # build/load images if needed
./scripts/16-k8-stack-verify.sh        # warmed: true, :8081 HTTP 200
```

---

## Phase 2 — GITOPS-001 Argo CD

**Goal:** Git becomes source of truth; both charts managed.

```bash
./scripts/13-argo-install.sh
./scripts/14-argo-verify.sh            # cxr-ui + cxr-analyzer Synced/Healthy
kubectl get application -n argocd
```

Argo UI: `kubectl port-forward svc/argocd-server -n argocd 8083:443` → https://localhost:8083

---

## Phase 3 — GitOps change loop (no helm upgrade)

**Goal:** Edit Git → push → Argo syncs.

```bash
# Example: bump deploy marker (CD-001 dry-run)
./scripts/cd-bump-deploy-marker.sh demo-$(date +%H%M%S)
git add helm/cxr-analyzer/values.yaml helm/cxr-ui/values.yaml
git commit -m "gitops demo: bump deploy marker"
git push origin main

# Watch sync (~1–3 min)
watch -n5 './scripts/14-argo-verify.sh'
kubectl get pods -n cxr-ui -o jsonpath='{range .items[*]}{.metadata.name}{" "}{.metadata.annotations.cxr\.gitops/deploy-marker}{"\n"}{end}'
```

---

## Phase 4 — CI extend (GitHub Actions)

**Goal:** GHA validates Helm charts on every push; full analyzer image build optional.

- **Always runs:** `validate-gitops` job — `helm lint` both charts
- **Optional:** full Docker build when `CXR_ANALYZER_REPO` + `CXR_ANALYZER_CHECKOUT` secret are set

```bash
gh run list --repo UdonsiKalu/cxr-ops-lab --workflow=build-k8-images.yml --limit 3
```

See `docs/BOOTCAMP-CI.md` for secret setup.

---

## Phase 5 — CD-001 (deploy marker via GHA)

**Goal:** After `build-k8-images` succeeds, `cd-gitops-bump.yml` commits marker → Argo rolls pods.

Trigger by pushing to `main` (paths under `helm/**`), or manually:

```bash
gh workflow run build-k8-images.yml --repo UdonsiKalu/cxr-ops-lab
```

---

## Phase 6 — OBS-001 Grafana

**Goal:** Dashboard stub for LOAD-003 / HPA evidence.

```bash
./scripts/07-observe-up.sh
# Grafana http://127.0.0.1:3001 — dashboard "CXR HPA Load (LOAD-003 / OBS-001)"
```

Primary LOAD-003 charts remain portfolio CSV + `plot_load_test.py`.

---

## Phase 7 — REL-K8 (optional execute)

```bash
# Terminal A
./scripts/k8-hpa-watch.sh

# Terminal B — from cxr-portfolio
./investigations/kill-analyzer-k8/run-kill-analyzer-k8.sh
./investigations/qdrant-outage-k8/run-qdrant-outage-k8.sh
```

---

## Phase 8 — SCALE-001 (optional)

See `cxr-portfolio/investigations/kubernetes-analyzer-saturation/SCALE-001-fixed-replicas.md` — disable HPA, set fixed `replicaCount`, Git push, Locust + plot.

---

## Quick reference

| Phase | ID | Daily command |
|-------|-----|---------------|
| GitOps loop | GITOPS-001 | edit `helm/*/values.yaml` → `git push` |
| Verify | — | `./scripts/14-argo-verify.sh` |
| Stack | — | `./scripts/16-k8-stack-verify.sh` |
| Load test | LOAD-003 | `CXR_LOAD_URL=http://127.0.0.1:8081 ./scripts/22-load-locust.sh` |

**:8251** rehearsal dev stays outside this loop.
