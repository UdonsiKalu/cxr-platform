#!/usr/bin/env bash
# Canonical repo paths (Phase 4 — no root symlinks). Source from other scripts.
set -euo pipefail

cxr_repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}

cxr_paths_init() {
  CXR_ROOT="$(cxr_repo_root)"
  CXR_COMPOSE_CORE="$CXR_ROOT/compose/core/compose.yaml"
  CXR_COMPOSE_HOST="$CXR_ROOT/compose/core/host.yaml"
  CXR_COMPOSE_BRIDGE="$CXR_ROOT/compose/core/bridge.yaml"
  CXR_COMPOSE_OBSERVE="$CXR_ROOT/compose/observe/compose.yaml"
  CXR_COMPOSE_OTEL_LINK="$CXR_ROOT/compose/observe/otel-link.yaml"
  CXR_COMPOSE_LABS="$CXR_ROOT/compose/labs"
  CXR_DOCKER_UI="$CXR_ROOT/docker/ui/Dockerfile"
  CXR_DOCKER_UI_COMPOSE="$CXR_ROOT/docker/ui/Dockerfile.compose"
  CXR_DOCKER_ANALYZER="$CXR_ROOT/docker/analyzer/Dockerfile"
  CXR_REQUIREMENTS_ANALYZER="$CXR_ROOT/docker/analyzer/requirements.txt"
  CXR_REQUIREMENTS_COMPOSE="$CXR_ROOT/docker/ui/requirements.txt"
  CXR_DOC_RUNBOOKS="$CXR_ROOT/docs/runbooks"
  CXR_DOC_MANUALS="$CXR_ROOT/docs/manuals"
  CXR_DOC_STANDARDS="$CXR_ROOT/docs/standards"
}

# Lab compose file (e.g. elk -> compose/labs/elk.yaml)
cxr_compose_lab() {
  local name="$1"
  echo "${CXR_ROOT:-$(cxr_repo_root)}/compose/labs/${name}.yaml"
}

# Manual TeX/PDF base path without extension (e.g. elk -> docs/manuals/elk/manual)
cxr_manual_doc_base() {
  local lab="$1"
  echo "${CXR_ROOT:-$(cxr_repo_root)}/docs/manuals/${lab}/manual"
}
