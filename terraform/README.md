# SW.5 — Terraform (local `kind`)

Reproducibly ensures cluster **`cxr-lab`** exists via the same script as manual deploy.

```bash
cd /home/udonsi-kalu/staging/cxr-ops-lab/terraform
export PATH="../bin:$PATH"
terraform init
terraform plan
terraform apply
```

**ADR:** `../docs/ADR-SW5-terraform-kind.md`

**Note:** `terraform destroy` removes the Terraform resource from state only; it does **not** delete the kind cluster. To remove the cluster:

```bash
kind delete cluster --name cxr-lab
```

After `terraform apply`, deploy the app with `../scripts/03-k8-up.sh` or `../scripts/12-k8-ensure.sh`.
