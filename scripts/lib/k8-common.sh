#!/usr/bin/env bash
# Shared Kubernetes helpers — Docker Desktop K8 (default) or kind (legacy).
# Set CXR_K8_RUNTIME=kind to force kind; default auto-detects active context.

cxr_k8_runtime() {
  if [[ -n "${CXR_K8_RUNTIME:-}" ]]; then
    echo "$CXR_K8_RUNTIME"
    return
  fi
  local ctx
  ctx="$(kubectl config current-context 2>/dev/null || true)"
  if [[ "$ctx" == "docker-desktop" ]]; then
    echo "docker-desktop"
    return
  fi
  if [[ "$ctx" == kind-* ]]; then
    echo "kind"
    return
  fi
  if kubectl config get-contexts -o name 2>/dev/null | grep -qx 'docker-desktop'; then
    echo "docker-desktop"
    return
  fi
  echo "kind"
}

ensure_k8_context() {
  local root="${1:?ROOT required}"
  export PATH="$root/bin:${PATH:-}"
  local runtime
  runtime="$(cxr_k8_runtime)"
  if [[ "$runtime" == "docker-desktop" ]]; then
    if ! kubectl config get-contexts -o name 2>/dev/null | grep -qx 'docker-desktop'; then
      echo "ERROR: docker-desktop context missing. Enable Kubernetes in Docker Desktop Settings." >&2
      echo "  Or run: $root/scripts/00-k8-desktop-enable.sh" >&2
      exit 1
    fi
    kubectl config use-context docker-desktop >/dev/null
    return 0
  fi
  ensure_kind_cluster "$root"
}

ensure_kind_cluster() {
  local cluster="${CXR_KIND_CLUSTER:-cxr-lab}"
  local root="${1:?ROOT required}"
  if kind get clusters 2>/dev/null | grep -qx "$cluster"; then
    return 0
  fi
  echo "kind cluster '$cluster' not found — creating (host.docker.internal for SQL/Qdrant)..."
  CXR_KIND_CLUSTER="$cluster" "$root/scripts/01-kind-cluster.sh"
}

load_image_to_cluster() {
  local image="${1:?image required}"
  local root="${2:?ROOT required}"
  local runtime
  runtime="$(cxr_k8_runtime)"
  if [[ "$runtime" == "docker-desktop" ]]; then
    echo "Image $image available to docker-desktop K8 (same Docker daemon — no kind load)"
    return 0
  fi
  local cluster="${CXR_KIND_CLUSTER:-cxr-lab}"
  ensure_kind_cluster "$root"
  kind load docker-image "$image" --name "$cluster"
}

require_kubectl() {
  local root="${1:?ROOT required}"
  export PATH="$root/bin:${PATH:-}"
  if kubectl cluster-info &>/dev/null; then
    return 0
  fi
  local runtime
  runtime="$(cxr_k8_runtime)"
  if [[ "$runtime" == "docker-desktop" ]]; then
    echo "ERROR: kubectl cannot reach docker-desktop cluster." >&2
    echo "  Enable Kubernetes in Docker Desktop → Settings → Kubernetes → Enable" >&2
    echo "  Then: $root/scripts/00-k8-desktop-enable.sh" >&2
  elif kind get clusters 2>/dev/null | grep -qx "${CXR_KIND_CLUSTER:-cxr-lab}"; then
    echo "ERROR: kind cluster exists but kubectl API is not responding." >&2
    echo "  Try: kind export kubeconfig --name ${CXR_KIND_CLUSTER:-cxr-lab}" >&2
  else
    echo "ERROR: no Kubernetes cluster. Run: $root/scripts/00-k8-desktop-enable.sh" >&2
    echo "  (legacy kind: $root/scripts/01-kind-cluster.sh)" >&2
  fi
  exit 1
}
