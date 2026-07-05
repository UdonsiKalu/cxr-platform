# Contributing to cxr-platform

Thank you for working in the CXR ops lab. This repo holds Docker/Kubernetes, observability, load testing, and lab automation for claims-analysis development.

## Before you open a PR

1. Read **[docs/GITHUB-NAMING-STANDARDS.md](docs/GITHUB-NAMING-STANDARDS.md)** — branch names, PR titles, commits, and body structure.  
2. Use the **[pull request template](.github/pull_request_template.md)** — lead with **why**, not file lists.  
3. Link investigation write-ups in **[cxr-portfolio](https://github.com/UdonsiKalu/cxr-portfolio)** when applicable.

## Naming at a glance

| Artifact | Format |
|----------|--------|
| **Branch** | `type/id-short-slug` — e.g. `fix/obs-003-shared-sql-connection` |
| **PR title** | `type(scope): outcome [ID]` — e.g. `fix(analyzer): prevent shared SQL connection errors under concurrent load [OBS-003]` |
| **Commit** (squash) | Same as PR title |

## Merge policy

- Target **`main`**  
- **Squash merge**; PR title becomes the commit message  
- Delete branch after merge  
- PR title check must pass (see `.github/workflows/pr-title-check.yml`)

## Study / evidence PRs

Performance and observability investigations use type **`study`** and IDs like **`PERF-008`**, **`OBS-003`**. Full rules and examples: [docs/GITHUB-NAMING-STANDARDS.md](docs/GITHUB-NAMING-STANDARDS.md).

## Local development

See `docs/` runbooks (K8 deploy, load gate, observe wiring) and `scripts/` entry points.
