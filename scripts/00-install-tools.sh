#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/bin"
mkdir -p "$BIN"

KIND_VER="v0.27.0"
if [[ ! -x "$BIN/kind" ]]; then
  curl -fsSL "https://kind.sigs.k8s.io/dl/${KIND_VER}/kind-linux-amd64" -o "$BIN/kind"
  chmod +x "$BIN/kind"
fi

if [[ ! -x "$BIN/kubectl" ]]; then
  KUBE_VER="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
  curl -fsSL "https://dl.k8s.io/release/${KUBE_VER}/bin/linux/amd64/kubectl" -o "$BIN/kubectl"
  chmod +x "$BIN/kubectl"
fi

HELM_VER="v3.16.4"
if [[ ! -x "$BIN/helm" ]]; then
  curl -fsSL "https://get.helm.sh/helm-${HELM_VER}-linux-amd64.tar.gz" | tar xz -C /tmp
  mv "/tmp/linux-amd64/helm" "$BIN/helm"
  chmod +x "$BIN/helm"
fi

TF_VER="1.9.8"
if [[ ! -x "$BIN/terraform" ]]; then
  curl -fsSL "https://releases.hashicorp.com/terraform/${TF_VER}/terraform_${TF_VER}_linux_amd64.zip" -o /tmp/terraform.zip
  unzip -qo /tmp/terraform.zip -d "$BIN"
  chmod +x "$BIN/terraform"
fi

ARGO_VER="v2.13.2"
if [[ ! -x "$BIN/argocd" ]]; then
  curl -fsSL "https://github.com/argoproj/argo-cd/releases/download/${ARGO_VER}/argocd-linux-amd64" -o "$BIN/argocd"
  chmod +x "$BIN/argocd"
fi

if ! command -v envsubst &>/dev/null; then
  echo "Note: install gettext-base for envsubst (apt install gettext-base)" >&2
fi

echo "Installed to $BIN"
"$BIN/kind" version
"$BIN/kubectl" version --client
"$BIN/helm" version --short
"$BIN/terraform" version | head -1
"$BIN/argocd" version --client --short 2>/dev/null || true
