# Replicate: Docker + rehearsal (do the same yourself)

Bootcamp artifacts live in **`cxr-ops-lab/`**. App source is always **rehearsal** `cxr-ui-prune-rehearsal/cxr-ui`. Production **`cxrlabs-dev/platform/infra`** is separate.

## A. SW.1 — Build image only

| Step | You do | Evidence |
|------|--------|----------|
| 1 | `cd staging/cxr-ops-lab` | — |
| 2 | `export PATH="$PWD/bin:$PATH"` (after `00-install-tools.sh` if needed) | `kind version` |
| 3 | `./scripts/02-build-and-load.sh` | Log ends with `Loaded cxr-ui:local` |
| 4 | `docker run --rm -p 3000:3000 cxr-ui:local` | Browser `http://localhost:3000` |

**What’s in the image:** Next.js production build of rehearsal UI only (no Python, no Qdrant).

---

## B. SW.2 — Compose (full CXR lab on :3000)

See **`docs/COMPOSE-CXR-MATRIX.md`** for what is / is not in compose vs :8251.

| Step | You do | Evidence |
|------|--------|----------|
| 1 | Ensure `cxrlabs-dev/claim_analysis_tools/analyze_sample.py` exists on host | `ls` that path |
| 2 | `./scripts/04-compose-up.sh` | `docker compose ps` both healthy |
| 3 | Open `http://localhost:3000` | Home loads |
| 4 | Open Claim Studio, Run analysis | F12: `POST /api/claim-studio/analyze` |
| 5 | If 500: `docker compose -f compose/core/compose.yaml -f compose/core/host.yaml logs cxr-ui` | SQL/Qdrant on host? ODBC in image? |

**What compose adds:**

- **qdrant** service (optional sidecar on **:6335**); with **Linux host overlay**, analyze uses **host** Qdrant **:6333**
- **volume** host `claim_analysis_tools` → `/analyzers` in container
- **env** `CXR_ANALYZER_SCRIPT=/analyzers/analyze_sample.py`
- **`compose/core/host.yaml`** (Linux): `network_mode: host` so spawned Python reaches **127.0.0.1:1433** SQL like :8251
- **Dockerfile.compose**: `python3`, **ODBC Driver 17**, `pyodbc`, `qdrant-client`

**One API path (memorize):**

```
Browser → POST /api/claim-studio/analyze
  → app/api/claim-studio/analyze/route.ts
  → lib/ingest + resolve-analyzer-script (reads CXR_ANALYZER_SCRIPT)
  → spawn python3 /analyzers/analyze_sample.py
```

Same pattern for **`/api/analyze-claim`** (paste page) with optional `lib/db.ts`.

---

## C. SW.3 — Kubernetes (already done on your machine)

| Step | You do | Evidence |
|------|--------|----------|
| 1 | `./scripts/01-kind-cluster.sh` | `kind get clusters` → `cxr-lab` |
| 2 | `./scripts/02-build-and-load.sh` | Image in kind |
| 3 | `./scripts/03-deploy.sh` | `kubectl get all -n cxr-ui` |
| 4 | `kubectl port-forward -n cxr-ui svc/cxr-ui 8081:3000` | UI at `:8081` |

K8 deploy today = **UI shell** unless you add the same volume/env as compose to `k8s/deployment.yaml`.

---

## D. Your checklist (copy into Personal notes)

- [ ] SW.1 `docker build` log saved  
- [ ] SW.2 `compose/core/compose.yaml` + `docker compose ps` screenshot  
- [ ] One API traced in F12 on **:3000** (compose) and **:8251** (dev)  
- [ ] SW.3 `kubectl get all` + URL note  
- [ ] ADR: “analyze in container uses mount, not baked Python tree”

---

## E. Stop / reset

```bash
cd staging/cxr-ops-lab
docker compose down
kind delete cluster --name cxr-lab   # only if tearing down K8
```
