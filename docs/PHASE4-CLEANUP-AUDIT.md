# Phase 4 cleanup audit

**Branch:** `chore/phase4-cleanup-audit`  
**Parent:** `chore/repo-git-hygiene` (PR #9)  
**Date:** 2026-07-05

## Purpose

Remove compatibility symlinks at repo root and `docs/` root. All callers use **canonical paths** via `scripts/lib/cxr-paths.sh`.

## Revert (full)

```bash
cd /home/udonsi-kalu/staging/cxr-ops-lab
git fetch origin
git checkout chore/repo-git-hygiene    # last state WITH symlinks
# or: git revert <phase4-merge-commit>..HEAD  (if merged as separate commits)
```

## Revert (partial)

Each Phase 4 commit is one logical step — use `git log --oneline` and `git revert <sha>`.

| Commit (after push) | Reverts |
|---------------------|---------|
| `paths: add cxr-paths.sh + update compose callers` | Restore symlink usage in scripts |
| `chore(docs): remove docs/ symlinks, fix internal links` | Restore docs symlinks |
| `chore(root): remove compose/docker symlinks` | Restore root symlinks |

## Path mapping (old symlink → canonical)

### Root compose

| Removed symlink | Canonical path |
|-----------------|----------------|
| `compose.yaml` | `compose/core/compose.yaml` |
| `compose.host.yaml` | `compose/core/host.yaml` |
| `compose.bridge.yaml` | `compose/core/bridge.yaml` |
| `compose.observe.yaml` | `compose/observe/compose.yaml` |
| `compose.otel-link.yaml` | `compose/observe/otel-link.yaml` |
| `compose.elk.yaml` | `compose/labs/elk.yaml` |
| `compose.kafka.yaml` | `compose/labs/kafka.yaml` |
| `compose.redis.yaml` | `compose/labs/redis.yaml` |
| `compose.graphql.yaml` | `compose/labs/graphql.yaml` |
| `compose.grpc.yaml` | `compose/labs/grpc.yaml` |
| `compose.vault.yaml` | `compose/labs/vault.yaml` |
| `compose.langfuse.yaml` | `compose/labs/langfuse.yaml` |

### Root docker

| Removed symlink | Canonical path |
|-----------------|----------------|
| `Dockerfile` | `docker/ui/Dockerfile` |
| `Dockerfile.compose` | `docker/ui/Dockerfile.compose` |
| `Dockerfile.analyzer` | `docker/analyzer/Dockerfile` |
| `requirements-analyzer-docker.txt` | `docker/analyzer/requirements.txt` |
| `requirements-compose.txt` | `docker/ui/requirements.txt` |

### Docs (removed symlinks at `docs/` root)

| Removed | Canonical |
|---------|-----------|
| `docs/K8-DEPLOY.md` | `docs/runbooks/k8-deploy.md` |
| `docs/K8-LOAD-OBSERVE-RUNBOOK.md` | `docs/runbooks/k8-load-observe.md` |
| `docs/K8-STACK-DEPLOY.md` | `docs/runbooks/k8-stack-deploy.md` |
| `docs/K8-M48-DEPENDENCIES.md` | `docs/runbooks/k8-m48-dependencies.md` |
| `docs/OBSERVE-WIRING.md` | `docs/runbooks/observe-wiring.md` |
| `docs/PERSISTENT-PORTS.md` | `docs/runbooks/persistent-ports.md` |
| `docs/GITOPS-PHASE-DEMO.md` | `docs/runbooks/gitops-phase-demo.md` |
| `docs/BOOTCAMP-CI.md` | `docs/runbooks/bootcamp-ci.md` |
| `docs/CI-GITHUB.md` | `docs/runbooks/ci-github.md` |
| `docs/COMPOSE-CXR-MATRIX.md` | `docs/runbooks/compose-matrix.md` |
| `docs/REPLICATE-DOCKER-OUTLINE.md` | `docs/runbooks/replicate-docker-outline.md` |
| `docs/TRIVY-POLICY.md` | `docs/standards/trivy-policy.md` |
| `docs/GITHUB-NAMING-STANDARDS.md` | `docs/standards/GITHUB-NAMING-STANDARDS.md` |
| `docs/ADR-SW5-terraform-kind.md` | `docs/adrs/ADR-SW5-terraform-kind.md` |
| `docs/CXR-*-LAB-MANUAL.{md,tex,pdf}` | `docs/manuals/<lab>/manual.{md,tex,pdf}` |

### Unchanged at repo root (by design)

`helm/`, `k8s/`, `observe/`, `load/`, `lab/`, `scripts/`, `systemd/`, `terraform/`, `evidence/`, `archive/`, `bin/`, `kind/`, `schemas/`

## External references (outside this repo — not auto-updated)

Portfolio and handoff may still link old paths, e.g.:

- `cxr-portfolio/...` → `docs/K8-LOAD-OBSERVE-RUNBOOK.md`
- `systemd/*.service` → absolute `/home/.../cxr-ops-lab/scripts/...` (unchanged)

Update portfolio in a follow-up PR if links break.

## Verification commands

```bash
test ! -e compose.observe.yaml && test -f compose/observe/compose.yaml
docker compose -f compose/observe/compose.yaml config -q
./scripts/07-observe-up.sh   # dry: config only if stack not running
git ls-files docs/K8-DEPLOY.md  # should be empty
```
