# SW.5 evidence — Terraform (local kind)

**Date:** 2026-05-28  
**Path:** `terraform/`  
**ADR:** `docs/ADR-SW5-terraform-kind.md`

## Apply (when Terraform is installed on host)

```bash
cd /home/udonsi-kalu/staging/cxr-ops-lab/terraform
export PATH="../bin:$PATH"
terraform init
terraform plan
terraform apply
```

**Expected plan:** `null_resource.kind_cluster` create or no-op if cluster already exists.

**Outputs:** `kube_context = kind-cxr-lab`, `next_steps` with `03-k8-up.sh`.

## Host note (2026-05-28)

`terraform` CLI was not on PATH during agent verify; install via `snap install terraform` or your package manager, then run plan/apply for portfolio snippet.

**Destroy:** `terraform destroy` does not delete the kind cluster — use `kind delete cluster --name cxr-lab`.
