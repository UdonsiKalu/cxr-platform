# ADR: SW.5 — Terraform provisions local `kind` (not cloud)

**Status:** Accepted (bootcamp)  
**Date:** 2026-05-28

## Context

Syllabus SW.5 requires a reproducible environment: `kind` cluster **or** cloud dev cluster, with an ADR explaining the choice.

## Decision

Use **Terraform `null_resource` + `local-exec`** to invoke `scripts/01-kind-cluster.sh` for cluster **`cxr-lab`**. No cloud provider in bootcamp scope.

## Consequences

- **Pros:** Same cluster name/kubecontext as manual scripts; `terraform plan` shows drift; no cloud cost.
- **Cons:** State is local; `terraform destroy` does not delete the kind cluster (documented in `terraform/README.md`).
- **Future:** Add a `azurerm`/`eks` module behind a variable when moving to cloud dev.

## Alternatives considered

| Option | Rejected because |
|--------|------------------|
| Cloud EKS/AKS now | Out of bootcamp scope; prod infra is separate |
| Terraform Docker provider for SW.2 only | Syllabus ties SW.5 to cluster provisioning after K8/Helm |
