# Raw Kubernetes manifests (SW.3 study)

| File | Purpose |
|------|---------|
| `namespace.yaml` | `cxr-ui` namespace |
| `deployment.yaml` | CXR UI (`cxr-ui:local`) |
| `service.yaml` | ClusterIP :3000 |

**Canonical deploy:** Helm chart at `../helm/cxr-ui/` via `../scripts/05-helm-install.sh` or `../scripts/03-k8-up.sh`.

Apply raw manifests only for learning:

```bash
./scripts/03-deploy.sh --raw
```

Smoke (nginx, no CXR build): `./scripts/03-deploy.sh --smoke`
