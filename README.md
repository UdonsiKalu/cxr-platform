# CXR ops lab — Starter track **SW.1–SW.8** (canonical)

**GitHub:** https://github.com/UdonsiKalu/cxr-platform

Bootcamp labs live here so **`cxrlabs-dev`** (production gateway/analysis compose) and **`:8251` rehearsal dev** stay untouched.

## Repo layout

| Path | Purpose |
|------|---------|
| [`compose/`](compose/README.md) | Docker Compose stacks (core, observe, labs) |
| [`docker/`](docker/README.md) | UI and analyzer Dockerfiles |
| [`docs/`](docs/README.md) | Runbooks, bootcamp manuals, standards |
| [`scripts/`](scripts/README.md) | Entry-point scripts (`00`–`27`) + `build/` |
| `helm/`, `k8s/`, `observe/`, `load/` | Runtime configs (unchanged) |

Root symlinks (`compose.observe.yaml`, `docs/K8-DEPLOY.md`, etc.) keep existing commands working.

**App source (build context):** `cxr-ui-prune-rehearsal/cxr-ui`  
**Rehearsal dev:** `npm run dev:rehearsal` on **:8251** (systemd) — not this folder.

Production CXR Docker (do not change for bootcamp):  
`cxrlabs-dev/claim_analysis_tools/platform/infra/` + service Dockerfiles under `platform/`.

## Prerequisites

- Docker
- **kind** + **kubectl** + **helm**:

```bash
cd /home/udonsi-kalu/staging/cxr-ops-lab
./scripts/00-install-tools.sh
export PATH="$PWD/bin:$PATH"
```

## Kubernetes (SW.3 + SW.4) — recommended

```bash
export PATH="/home/udonsi-kalu/staging/cxr-ops-lab/bin:$PATH"
./scripts/03-k8-up.sh
kubectl port-forward -n cxr-ui svc/cxr-ui 8081:3000 --address=127.0.0.1
```

Browser: **http://localhost:8081**

Full guide: **`docs/K8-DEPLOY.md`**

| Step | Script |
|------|--------|
| One-shot deploy | `03-k8-up.sh` |
| Ensure + systemd | `12-k8-ensure.sh` (used by `cxr-k8-forward.service`) |
| Helm only | `05-helm-install.sh` |
| Raw manifests (study) | `03-deploy.sh --raw` |
| Terraform cluster (SW.5) | `terraform/` |
| Argo CD (SW.8) | `13-argo-install.sh` |

## SW.2 — Compose (UI + Qdrant + analyzers mount)

```bash
./scripts/04-compose-up.sh
```

- UI: http://localhost:3000  
- Qdrant: http://localhost:6333  
- Replicate steps: **`docs/REPLICATE-DOCKER-OUTLINE.md`**  
- Full platform syllabus map: **`docs/PLATFORM-SYLLABUS-MAP.md`**

## Teardown

```bash
docker compose down    # from cxr-ops-lab/
kind delete cluster --name cxr-lab
```

## Rehearsal duplicates

`cxr-ui-prune-rehearsal/cxr-ui/deploy/k8s/` and `scripts/ops/` mirror manifests for study; **builds use this repo’s `Dockerfile` + `scripts/02-build-and-load.sh`.**
