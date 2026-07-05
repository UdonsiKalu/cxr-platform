# SW.6 / SW.7 — GitHub Actions

## Rehearsal repo (SW.6 build — simplest)

`cxr-ui-rehearsal` has `.github/workflows/ci.yml`: `npm ci` + `npm run build` on every push.

```bash
cd cxr-ui-prune-rehearsal/cxr-ui
git add .github/workflows/ci.yml
git push
```

Open **Actions** on https://github.com/UdonsiKalu/cxr-ui-rehearsal

## Staging `cxr-saas` (SW.6 + SW.7 docker + Trivy)

Workflow: `staging/.github/workflows/cxr-bootcamp-ci.yml`

The UI is **not** in `cxr-saas` (too large); CI checks out the private rehearsal repo.

1. GitHub → **cxr-saas** → **Settings** → **Secrets and variables** → **Actions**
2. New secret: **`CXR_REHEARSAL_CHECKOUT`** = fine-grained PAT with **Contents: read** on `cxr-ui-rehearsal`
3. Push `cxr-ops-lab/` and `.github/workflows/cxr-bootcamp-ci.yml` on a branch; open PR or push to trigger

Optional variable **`CXR_REHEARSAL_REF`** (default `chore/rehearsal-high-risk-batch11`).

## Local parity (before push)

```bash
cd cxr-ui-prune-rehearsal/cxr-ui
npm ci && npm run build
```
