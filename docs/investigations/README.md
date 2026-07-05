# Investigation PRs — cxr-platform

**Repo:** https://github.com/UdonsiKalu/cxr-platform  
**Local tree:** `staging/cxr-ops-lab/`  
**Naming rules:** [GITHUB-NAMING-STANDARDS.md](../GITHUB-NAMING-STANDARDS.md)

Open performance/observability PRs are **one arc split for review**, not three unrelated features. Full write-ups live in **cxr-portfolio** under `investigations/kubernetes-analyzer-saturation/studies/`.

---

## PR map

| PR | Branch | Title (standard) | ID | Deep doc |
|----|--------|------------------|-----|----------|
| [#4](https://github.com/UdonsiKalu/cxr-platform/pull/4) ✅ | `feat/live-ops-synthetic-stream` | `feat(live-ops): add synthetic traffic stream and Fault Gym orchestration` | — | [live-operations-center.md](../operations/live-operations-center.md) |
| [#1](https://github.com/UdonsiKalu/cxr-platform/pull/1) | `study/perf-008-keda-ab-backpressure` | `feat(k8s): add KEDA A/B harness and fix replica metrics in load gate [PERF-008]` | PERF-008 | [PERF-008 study](https://github.com/UdonsiKalu/cxr-portfolio/blob/master/investigations/kubernetes-analyzer-saturation/studies/PERF-008-queue-depth-autoscaling.md) |
| [#2](https://github.com/UdonsiKalu/cxr-platform/pull/2) | `study/perf-009-jaeger-tail-latency` | `study(observe): document Jaeger tail latency attribution at 200 users [PERF-009]` | PERF-009 | [PERF-009 study](https://github.com/UdonsiKalu/cxr-portfolio/blob/master/investigations/kubernetes-analyzer-saturation/studies/PERF-009-jaeger-tail-latency.md) |
| [#3](https://github.com/UdonsiKalu/cxr-platform/pull/3) | `fix/obs-003-shared-sql-connection` | `fix(analyzer): prevent shared SQL connection errors under concurrent load [OBS-003]` | OBS-003 | [OBS-003 study](https://github.com/UdonsiKalu/cxr-portfolio/blob/master/investigations/kubernetes-analyzer-saturation/studies/OBS-003-shared-sql-connection.md) |

---

## How the branches stack

```
main
 └── PR #1  study/perf-008-keda-ab-backpressure
      └── PR #2  study/perf-009-jaeger-tail-latency
           └── PR #3  fix/obs-003-shared-sql-connection
```

- Each PR targets **`main`**, not the previous PR branch.
- Later branches **contain** earlier commits (cumulative), so file lists overlap.
- **Merge order:** #1 → #2 → #3, **or** merge #3 only and close #1/#2.

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
| **Runbook / reproduce** | `docs/K8-LOAD-OBSERVE-RUNBOOK.md`, `scripts/` |

When closing a study: update the study `.md`, evidence folder, one CHANGELOG line, and the PR body link to the study doc.
