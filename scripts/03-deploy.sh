#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/bin:${PATH:-}"
K8S="$ROOT/k8s"

kubectl apply -f "$K8S/namespace.yaml"

if [[ "${1:-}" == "--smoke" ]]; then
  kubectl apply -f "$K8S/deployment-smoke.yaml"
  kubectl apply -f "$K8S/service-smoke.yaml"
  echo "Smoke deploy (nginx). Port-forward: kubectl port-forward -n cxr-ui svc/cxr-ui 8080:80"
elif [[ "${1:-}" == "--raw" ]]; then
  kubectl apply -f "$K8S/deployment.yaml"
  kubectl apply -f "$K8S/service.yaml"
  echo "Raw manifests (SW.3 study). Port-forward: kubectl port-forward -n cxr-ui svc/cxr-ui 8081:3000"
else
  echo "Default deploy uses Helm (SW.4). Running 05-helm-install.sh ..."
  "$ROOT/scripts/05-helm-install.sh"
fi

kubectl get all -n cxr-ui
