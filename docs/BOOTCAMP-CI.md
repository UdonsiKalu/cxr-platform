# Bootcamp CI policy

| Repo | Role | Workflow |
|------|------|----------|
| **cxr-ui-rehearsal** | Canonical app CI (**CI-001**) | `ci.yml` — build, Playwright, Docker, Trivy |
| **cxr-ops-lab** | K8 images + GitOps values | `build-k8-images.yml`, `cd-gitops-bump.yml` |

Do **not** duplicate full app CI in ops-lab. Ops-lab validates **Dockerfile.analyzer** smoke build and bumps **`gitOpsDeployMarker`** for **CD-001** → Argo sync.
