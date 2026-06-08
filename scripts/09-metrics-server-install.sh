#!/usr/bin/env bash
# Install metrics-server (required for CPU-based HPA on kind).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/bin:${PATH:-}"
# shellcheck source=lib/kind-common.sh
source "$ROOT/scripts/lib/kind-common.sh"

require_kubectl "$ROOT"

if kubectl get deployment metrics-server -n kube-system &>/dev/null; then
  echo "metrics-server already installed"
else
  echo "Installing metrics-server..."
  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
fi

kubectl patch deployment metrics-server -n kube-system --type=json -p='[
  {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"},
  {"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname"}
]' 2>/dev/null || true

kubectl rollout status deployment/metrics-server -n kube-system --timeout=120s
echo "metrics-server ready — kubectl top nodes"
