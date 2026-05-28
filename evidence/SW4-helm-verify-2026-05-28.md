# SW.4 evidence — Helm chart `cxr-ui`

**Date:** 2026-05-28  
**Chart:** `helm/cxr-ui/` (Chart.yaml `0.1.0`)  
**Values:** `image.repository=cxr-ui`, `image.tag=local`, `replicaCount=1`, `service.port=3000`

## Install

```bash
export PATH="/home/udonsi-kalu/staging/cxr-ops-lab/bin:$PATH"
./scripts/05-helm-install.sh
```

## helm list -n cxr-ui

```
NAME  	NAMESPACE	REVISION	STATUS  	CHART       	APP VERSION
cxr-ui	cxr-ui   	1       	deployed	cxr-ui-0.1.0	1.0.0
```

## Upgrade / rollback (reference)

```bash
helm upgrade cxr-ui ./helm/cxr-ui -n cxr-ui
helm history cxr-ui -n cxr-ui
helm rollback cxr-ui 1 -n cxr-ui
```

Raw SW.3 manifests remain in `k8s/`; use `03-deploy.sh --raw` only for study.
