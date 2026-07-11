# GIT-001 — Keep Helm values in Git (avoid Argo drift)

**Problem:** Live `helm upgrade` or Argo Application Helm **parameters** fix the cluster today, then Argo auto-sync from stale Git `main` undoes them tomorrow.

**Rule:** Edit `helm/*/values.yaml` → commit → push → Argo sync. Do not leave long-lived parameter overrides on the Application CR.

---

## Lab baseline (GATE-002 → GIT-001)

| Chart | Knob | Value | Why |
|-------|------|-------|-----|
| `cxr-analyzer` | `autoscaling.maxReplicas` | **8** | GATE-002 winner (c4) |
| `cxr-analyzer` | `autoscaling.minReplicas` | **2** | Hardened vs winner’s `1` (still gate-pass; fewer cold starts) |
| `cxr-analyzer` | `autoscaling.keda.prometheus.p95ThresholdMs` | **2000** | GATE-002 / PERF-008 Experiment A |
| `cxr-ui` | `autoscaling.maxReplicas` | **4** | Winner; UI max **5** failed @200 (c1, 116 failures/s) |

Portfolio write-up: [GATE-002 study](https://github.com/UdonsiKalu/cxr-portfolio/blob/master/investigations/kubernetes-analyzer-saturation/studies/GATE-002-keda-helm-grid-study.md) · issue [#24](https://github.com/UdonsiKalu/cxr-portfolio/issues/24).

---

## Safe change loop

```bash
cd ~/staging/cxr-ops-lab   # local clone of UdonsiKalu/cxr-platform
# edit helm/cxr-analyzer/values.yaml and/or helm/cxr-ui/values.yaml
git checkout -b fix/…-helm-values
git add helm/cxr-analyzer/values.yaml helm/cxr-ui/values.yaml
git commit -m "fix(gitops): align Helm defaults with GATE-002 baseline [GIT-001]"
git push -u origin HEAD
# open PR → merge to main
./scripts/14-argo-verify.sh   # after merge: Synced/Healthy
```

Temporary lab override (emergency only — reverse before next sync day):

```bash
# Prefer not to. If you must patch live, copy the same numbers into values.yaml the same day.
kubectl -n argocd get application cxr-analyzer -o yaml | grep -A20 'helm:'
```

---

## Verify no drift

```bash
# Desired from Git (after pull of main)
rg 'minReplicas|maxReplicas|p95Threshold' helm/cxr-analyzer/values.yaml helm/cxr-ui/values.yaml

# Live cluster
kubectl -n cxr-ui get hpa,scaledobject 2>/dev/null
kubectl -n argocd get application cxr-ui cxr-analyzer
```

If Application status is **OutOfSync**, either push the missing values or discard an accidental live edit (`argocd app sync` / selfHeal).

Related demo walkthrough: [gitops-phase-demo.md](./gitops-phase-demo.md).
