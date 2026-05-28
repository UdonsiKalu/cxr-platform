# SW.3 evidence — Kubernetes (cxr-lab)

**Date:** 2026-05-28  
**Cluster:** `kind` / `cxr-lab`  
**Namespace:** `cxr-ui`  
**Deploy:** Helm (`helm/cxr-ui`) via `scripts/12-k8-ensure.sh` (canonical; raw manifests in `k8s/` for study)

## kubectl get all -n cxr-ui

```
NAME                          READY   STATUS    RESTARTS   AGE
pod/cxr-ui-77b7b7f684-bz85h   1/1     Running   0          ~1m

NAME             TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
service/cxr-ui   ClusterIP   10.96.187.56   <none>        3000/TCP   ~1m

NAME                     READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/cxr-ui   1/1     1            1           ~1m
```

**Image:** `cxr-ui:local` (rehearsal UI, SW.1 Dockerfile)

## URL access

| Forward | URL | HTTP |
|---------|-----|------|
| `kubectl port-forward -n cxr-ui svc/cxr-ui 8081:3000 --address=127.0.0.1` | http://localhost:8081 | **200** (`X-Powered-By: Next.js`) |

## Commands used

```bash
export PATH="/home/udonsi-kalu/staging/cxr-ops-lab/bin:$PATH"
./scripts/00-install-tools.sh   # kind, kubectl, helm
./scripts/12-k8-ensure.sh
kubectl port-forward -n cxr-ui svc/cxr-ui 8081:3000 --address=127.0.0.1
```

One-shot equivalent: `./scripts/03-k8-up.sh`

## Notes

- **:8081** = host port-forward only (lab); prod would use Ingress/LB.
- Full Claim Studio analyze: **:8251** (dev) or **:3000** (Compose); K8 pod is UI shell without analyzer mounts.
- Dependencies diagram: `docs/K8-M48-DEPENDENCIES.md`
