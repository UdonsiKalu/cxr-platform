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

echo "Installed to $BIN"
"$BIN/kind" version
"$BIN/kubectl" version --client
"$BIN/helm" version --short
