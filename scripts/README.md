# Scripts index

Numbered scripts (`00`–`27`) stay at **repo root of `scripts/`** — bootcamp syllabus and systemd reference them by name.

| Subfolder | Contents |
|-----------|----------|
| [build/](build/) | Analyzer Docker builds, lab manual PDF generators |
| [lib/](lib/) | Shared Python/shell helpers (`k8-common.sh`, load gate) |

## Domain map (top-level scripts)

| Domain | Examples |
|--------|----------|
| **Tools / kind** | `00-install-tools.sh`, `01-kind-cluster.sh` |
| **Build / images** | `02-build-and-load.sh` → wrappers to `build/` |
| **K8 deploy** | `03-k8-up.sh`, `03-k8-stack-up.sh`, `06-helm-install-stack.sh` |
| **Compose** | `04-compose-up.sh`, `16-elk-up.sh`, `17-redis-up.sh` |
| **Observe** | `07-observe-up.sh`, `22-load-locust.sh`, `23-k8-load-observe-up.sh` |
| **Live ops** | `25-synthetic-readiness-up.sh`, `26-live-ops-stream-up.sh`, `27-live-ops-fault-scenario.sh` |
| **GitOps / Argo** | `13-argo-install.sh`, `cd-bump-deploy-marker.sh` |
| **Load / perf** | `k8-load-gate.sh`, `k8-load-tuner.sh` (on study branches) |
| **Dev stack** | `cxr-dev-stack.sh` |

Build scripts moved under `build/` expose **wrappers** at the old paths (e.g. `./scripts/build-k8-manual-pdf.sh`).
