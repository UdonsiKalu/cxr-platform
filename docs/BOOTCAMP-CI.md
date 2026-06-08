# Bootcamp CI policy

| Repo | Role | Workflow |
|------|------|----------|
| **cxr-ui-rehearsal** | Canonical app CI (**CI-001**) | `ci.yml` — build, Playwright, Docker, Trivy |
| **cxr-ops-lab** | K8 images + GitOps values | `build-k8-images.yml`, `cd-gitops-bump.yml` |

Do **not** duplicate full app CI in ops-lab. **`build-k8-images`** always lints Helm charts on push. Full **`Dockerfile.analyzer`** build on GHA is **optional** — analyzer source is local (`cxrlabs-dev/claim_analysis_tools`), not in this repo.

### Enable full analyzer build on GHA (optional)

1. Push analyzer files (`analyzer_service_app.py`, `archetype_catalog_v3_1_master/`, …) to a GitHub repo you control.
2. **cxr-ops-lab** → Settings → Variables → **`CXR_ANALYZER_REPO`** (e.g. `UdonsiKalu/my-cxr-analyzer`).
3. Settings → Secrets → **`CXR_ANALYZER_CHECKOUT`** = PAT with **Contents: read** on that repo.

Local build (always works):

```bash
./scripts/02-build-analyzer-docker-only.sh
# or: CXR_ANALYZER_SRC=../cxrlabs-dev/claim_analysis_tools ./scripts/02-build-analyzer-docker-only.sh
```

Phased demo runbook: **`docs/GITOPS-PHASE-DEMO.md`**
