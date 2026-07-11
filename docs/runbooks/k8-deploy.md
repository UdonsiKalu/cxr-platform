# CXR Kubernetes deploy (bootcamp SW.3–SW.8)

Local **`kind`** cluster **`cxr-lab`** runs the rehearsal CXR UI image. This does **not** change production `cxrlabs-dev/platform/infra`.

## Quick start (recommended)

**Full stack (Terraform + Helm + Argo + test):**

```bash
cd /home/udonsi-kalu/staging/cxr-ops-lab
export PATH="$PWD/bin:$PATH"
./scripts/15-e2e-deploy.sh
```

**App only:**

```bash
./scripts/03-k8-up.sh
kubectl port-forward -n cxr-ui svc/cxr-ui 8081:3000 --address=127.0.0.1
```

| URL | Service |
|-----|---------|
| http://localhost:8081 | CXR UI (K8) |
| https://localhost:8083 | Argo CD UI |

Persistent access: `systemctl --user enable --now cxr-k8-forward` (see `docs/PERSISTENT-PORTS.md`).

## Layered syllabus map

| Step | Script / path | Syllabus |
|------|----------------|----------|
| Cluster | `01-kind-cluster.sh` | SW.3 |
| Image | `02-build-and-load.sh` → `cxr-ui:local` | SW.1 → SW.3 |
| Deploy | `05-helm-install.sh` (chart `helm/cxr-ui/`) | SW.4 (canonical) |
| Raw manifests | `03-deploy.sh --raw` | SW.3 study only |
| Repro cluster | `terraform/` + `terraform apply` | SW.5 |
| GitOps | `13-argo-install.sh` + `k8s/argocd/` | SW.8 |

**Git source of truth:** https://github.com/UdonsiKalu/cxr-ops-lab (`helm/cxr-ui` at repo root).

**One-shot:** `03-k8-up.sh` = cluster + build/load + Helm deploy (UI only).

**Full stack (UI + analyzer + HPA):** `03-k8-stack-up.sh` — see [`docs/K8-STACK-DEPLOY.md`](K8-STACK-DEPLOY.md).

## Ports (do not confuse)

| Port | Runtime |
|------|---------|
| **8251** | Rehearsal `npm` dev (full analyze) |
| **3000** | Docker Compose SW.2 lab |
| **8081** | K8 — host `kubectl port-forward` → Service `:3000` |

Pod listens on **3000 inside the cluster**; forward maps it to the host.

## Dependencies (M4.8)

SQL Server, Qdrant, and Python analyzers are **out-of-cluster** for bootcamp K8. The SW.1 image in the pod is UI-only; full Claim Studio analyze uses **:8251** or **:3000** Compose. See `docs/K8-M48-DEPENDENCIES.md`.

## Full manual (PDF)

- **Markdown:** `docs/CXR-K8-DEPLOYMENT-MANUAL.md`
- **LaTeX PDF:** `docs/CXR-K8-DEPLOYMENT-MANUAL.pdf` — build with `./scripts/build-k8-manual-pdf.sh`

## OpenTelemetry (SW.11)

- **Lab manual:** `docs/CXR-OTEL-LAB-MANUAL.md` / `.pdf` — `./scripts/build-otel-manual-pdf.sh`
- **Stack:** `./scripts/07-observe-up.sh` (Prometheus, Grafana, Jaeger, OTel Collector)
- **Env:** `.env.otel.example`

## Teardown

```bash
kind delete cluster --name cxr-lab
```
