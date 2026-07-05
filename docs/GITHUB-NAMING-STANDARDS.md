# GitHub naming standards — cxr-platform

**Purpose:** One reference for branch names, PR titles, commits, and issues across CXR GitHub repos.  
**Applies to:** [cxr-platform](https://github.com/UdonsiKalu/cxr-platform) (this repo), [cxr-ui](https://github.com/UdonsiKalu/cxr-ui), [cxr-portfolio](https://github.com/UdonsiKalu/cxr-portfolio) (issues + study docs).

**Enforcement:** PR title check workflow (`.github/workflows/pr-title-check.yml`) on pull requests to `main`.

---

## Cardinal rules (industry baseline)

These are what most mature teams converge on — not one vendor spec, but the de facto stack:

| # | Rule | Why |
|---|------|-----|
| 1 | **Outcome over implementation** — titles name the *problem solved* or *capability added*, not files, image tags, or script names | Reviewers and `git log` stay readable |
| 2 | **[Conventional Commits](https://www.conventionalcommits.org/)** shape for PR titles and squash-merge commits | Machine-parseable history; works with release/changelog tooling |
| 3 | **`type/short-kebab-slug` branches** | Scannable branch lists; matches GitHub Flow / GitLab Flow |
| 4 | **Investigation ID in suffix, not as the whole title** — e.g. `[OBS-003]` | Links portfolio evidence without jargon-first titles |
| 5 | **Imperative mood** — `fix`, `add`, `prevent`, not `fixed` or `fixes` | Git convention since Git itself |
| 6 | **One PR = one intent** | Clean revert and review |
| 7 | **PR body leads with “Why”** | See [.github/pull_request_template.md](../.github/pull_request_template.md) |

---

## PR title format

```text
<type>(<scope>): <outcome in plain English> [<ID>]
```

| Part | Required | Examples |
|------|----------|----------|
| **type** | Yes | `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `ci`, `perf`, **`study`** |
| **scope** | Recommended | `analyzer`, `k8s`, `observe`, `live-ops`, `ui`, `helm` |
| **outcome** | Yes | Lowercase after colon; imperative; ≤ ~72 chars preferred |
| **ID** | When tied to investigation | `[PERF-008]`, `[OBS-003]`, `[GATE-002]` |

### Allowed types

Standard (Conventional Commits): `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.

**CXR extension:** `study` — investigation PRs that add scripts, evidence, or runbooks without changing production behavior yet.

### Good vs bad PR titles

| Bad | Good |
|-----|------|
| `OBS-003: perf009-sql image layer for thread-safe ContextCollector` | `fix(analyzer): prevent shared SQL connection errors under concurrent load [OBS-003]` |
| `PERF-009: Jaeger attribution scripts and replay evidence` | `study(observe): document Jaeger tail latency attribution at 200 users [PERF-009]` |
| `PERF-008: OBS-002 replica truth, analyzer metrics scrape, KEDA A/B harness` | `feat(k8s): add KEDA A/B harness and fix replica metrics in load gate [PERF-008]` |
| `Update Dockerfile.analyzer.perf008-layer` | `fix(analyzer): serialize pyodbc access in ContextCollector [OBS-003]` |

**Never in the title:** Docker image tags (`perf009-sql`), filenames, `scripts/foo.sh`, internal codenames alone.

---

## Branch name format

```text
<type>/<id>-<short-kebab-slug>
```

| Type prefix | Use when |
|-------------|----------|
| `feat/` | New user- or operator-facing capability |
| `fix/` | Bug or correctness fix |
| `study/` | Investigation, evidence, load-gate experiments |
| `docs/` | Documentation only |
| `chore/` | CI, deps, formatting, non-behavior refactors |
| `hotfix/` | Urgent production fix (rare in lab repos) |

### Examples

| Investigation | Branch |
|---------------|--------|
| PERF-008 KEDA A/B | `study/perf-008-keda-ab-backpressure` |
| PERF-009 Jaeger | `study/perf-009-jaeger-tail-latency` |
| OBS-003 SQL | `fix/obs-003-shared-sql-connection` |
| Live Ops stream | `feat/live-ops-synthetic-stream` |

**Rules:**

- Lowercase kebab-case only (`a-z`, `0-9`, `-`)
- Include investigation ID when one exists (`perf-008`, `obs-003`)
- Do not mix unrelated IDs (e.g. `perf009` slug for an `OBS-003` fix)
- Avoid bare `feature/` — use `feat/` or `study/` for clarity
- **Renaming a branch closes its open PR** on GitHub — rename before opening a PR, or open a new PR from the renamed branch (see investigations README note on #1–#3 → #6–#8)

---

## Commit messages

Same grammar as PR titles. With **squash merge**, the PR title becomes the commit on `main` — keep PR titles clean.

```text
fix(analyzer): serialize pyodbc access in ContextCollector [OBS-003]
```

Multi-commit branches may use shorter subject lines; the squash title must still follow the PR format.

---

## Issue titles (cxr-portfolio)

```text
<ID>: <problem statement in plain English>
```

Examples:

- `OBS-003: Shared SQL connection busy under concurrent /analyze`
- `PERF-009: Jaeger tail latency attribution at 200 users`
- `PERF-008: Queue depth and backpressure autoscaling experiment`

Issue = **problem**. PR = **solution or study artifact**.

---

## Study doc filenames (cxr-portfolio)

```text
<ID>-<kebab-case-topic>.md
```

Examples: `OBS-003-shared-sql-connection.md`, `PERF-009-jaeger-tail-latency.md`

---

## PR body structure

Required sections (template enforces):

1. **Why this PR exists** — symptoms, impact, tracking issue  
2. **Finding / verdict** — what we learned (studies)  
3. **What this PR changes** — files, images, scripts *(implementation here)*  
4. **What this PR does NOT change** — separate findings  
5. **Verification** — commands/checks  
6. **Deep doc** — link to portfolio study  

Index: [docs/investigations/README.md](investigations/README.md)

---

## Merge strategy

- **Squash merge** to `main` preferred  
- Use **PR title** as squash commit message  
- Delete branch after merge  

---

## CI check

Workflow: `.github/workflows/pr-title-check.yml`

Validates PR titles against:

```regex
^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert|study)(\([a-z0-9_-]+\))!:? .+(\[(OBS|PERF|GATE|LOAD|OPS|GIT|DOC|SCALE|CHAOS|DEP)-[0-9]+\])?$
```

Breaking change: add `!` after scope, e.g. `feat(k8s)!: change default analyzer image tag`.

---

## Quick checklist (before opening a PR)

- [ ] Branch name: `type/id-slug`  
- [ ] PR title: outcome-first Conventional Commits + `[ID]`  
- [ ] PR body: “Why” before “What”  
- [ ] Issue/study doc linked  
- [ ] No secrets or `.env` in commits  

---

## Related

- [CONTRIBUTING.md](../CONTRIBUTING.md) — entry point  
- [investigations/README.md](investigations/README.md) — open study PR map  
- [cxr-portfolio GITHUB-WORKFLOW.md](https://github.com/UdonsiKalu/cxr-portfolio/blob/master/operations/GITHUB-WORKFLOW.md) — portfolio issue flow  
