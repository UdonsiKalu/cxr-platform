# Investigation PRs — cxr-platform

**Repo:** https://github.com/UdonsiKalu/cxr-platform  
**Local tree:** `staging/cxr-ops-lab/`  
**Naming rules:** [GITHUB-NAMING-STANDARDS.md](../GITHUB-NAMING-STANDARDS.md)

Open performance/observability PRs are **one arc split for review**, not three unrelated features. Full write-ups live in **cxr-portfolio** under `investigations/kubernetes-analyzer-saturation/studies/`.

---

## PR map

| PR | Branch | Title (standard) | ID | Deep doc |
|----|--------|------------------|-----|----------|
| [#4](https://github.com/UdonsiKalu/cxr-platform/pull/4) ✅ | `feat/live-ops-stream` | `feat(live-ops): synthetic stream, Fault Gym orchestration, observe wiring` | — | [live-operations-center.md](../operations/live-operations-center.md) |
| [#6](https://github.com/UdonsiKalu/cxr-platform/pull/6) | `study/perf-008-keda-ab-backpressure` | `feat(k8s): add KEDA A/B harness and fix replica metrics in load gate [PERF-008]` | PERF-008 | [PERF-008 study](https://github.com/UdonsiKalu/cxr-portfolio/blob/master/investigations/kubernetes-analyzer-saturation/studies/PERF-008-queue-depth-autoscaling.md) |
| [#7](https://github.com/UdonsiKalu/cxr-platform/pull/7) | `study/perf-009-jaeger-tail-latency` | `study(observe): document Jaeger tail latency attribution at 200 users [PERF-009]` | PERF-009 | [PERF-009 study](https://github.com/UdonsiKalu/cxr-portfolio/blob/master/investigations/kubernetes-analyzer-saturation/studies/PERF-009-jaeger-tail-latency.md) |
| [#8](https://github.com/UdonsiKalu/cxr-platform/pull/8) | `fix/obs-003-shared-sql-connection` | `fix(analyzer): prevent shared SQL connection errors under concurrent load [OBS-003]` | OBS-003 | [OBS-003 study](https://github.com/UdonsiKalu/cxr-portfolio/blob/master/investigations/kubernetes-analyzer-saturation/studies/OBS-003-shared-sql-connection.md) |
| [#5](https://github.com/UdonsiKalu/cxr-platform/pull/5) | `chore/github-naming-standards` | `docs(github): add naming standards and PR title check workflow` | — | [GITHUB-NAMING-STANDARDS.md](../GITHUB-NAMING-STANDARDS.md) |

> **Note:** PRs #1–#3 were closed when branches were renamed (2026-07-05). Use #6–#8 for the investigation arc.

---

## How the branches stack

```
main
 └── PR #6  study/perf-008-keda-ab-backpressure
      └── PR #7  study/perf-009-jaeger-tail-latency
           └── PR #8  fix/obs-003-shared-sql-connection
```

- Each PR targets **`main`**, not the previous PR branch.
- Later branches **contain** earlier commits (cumulative), so file lists overlap.
- **Merge order:** #6 → #7 → #8, **or** merge #8 only and close #6/#7.

---

## Label glossary

| ID | Meaning |
|----|---------|
| **PERF-008** | Performance study — queue/backpressure **autoscaling** signals (KEDA A vs B) |
| **PERF-009** | Performance study — **Jaeger attribution** of tail latency (what span widens p95) |
| **OBS-002** | Observability fix — Grafana/gate read **Deployment readyReplicas**, not removed HPA |
| **OBS-003** | Observability/correctness fix — **shared SQL connection** unsafe under concurrent `/analyze` |
| **GATE-002** | Earlier KEDA + Helm grid study (prerequisite context for PERF-008) |

---

## Where to put new notes

| Need | Put it here |
|------|-------------|
| **Reviewer-facing story** | `cxr-portfolio/investigations/kubernetes-analyzer-saturation/studies/<ID>-<topic>.md` |
| **Failure arc summary** | `cxr-portfolio/failures/README.md` |
| **Dated journal entry** | `cxr-portfolio/CHANGELOG.md` |
| **PR ↔ branch ↔ doc index** | This file |
| **Naming rules** | [GITHUB-NAMING-STANDARDS.md](../GITHUB-NAMING-STANDARDS.md) |
| **Runbook / reproduce** | `docs/runbooks/k8-load-observe.md`, `scripts/` |

When closing a study: update the study `.md`, evidence folder, one CHANGELOG line, and the PR body link to the study doc.
