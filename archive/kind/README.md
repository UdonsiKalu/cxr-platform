# kind lab — parked (use Docker Desktop K8)

**Default K8 path (2026-06-08):** `scripts/03-k8-desktop-stack-up.sh` on context **`docker-desktop`**.

These **kind** assets remain for syllabus **LOAD-005** (multi-node) if you revisit later — not required for LOAD-003 HPA on Desktop.

| Path | Purpose |
|------|---------|
| `../../kind/cxr-lab.yaml` | Single-node kind config |
| `../../kind/cxr-lab-expanded.yaml` | 3-node kind (LOAD-004/005) |
| `../../scripts/01-kind-cluster.sh` | Create single-node cluster |
| `../../scripts/01-kind-recreate-expanded.sh` | 3-node recreate |
| `../../scripts/04-kind-load-images-only.sh` | `kind load` images |
| `../../scripts/03-k8-stack-up.sh` | Legacy one-shot (kind) — use **`03-k8-desktop-stack-up.sh`** instead |
| `../../scripts/02-build-and-load.sh` | Build + kind load |

Do **not** delete without updating `scripts/lib/k8-common.sh` (`ensure_kind_cluster` still references `01-kind-cluster.sh` when context is **kind-***).

