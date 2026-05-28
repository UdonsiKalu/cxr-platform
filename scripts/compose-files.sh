#!/usr/bin/env bash
# Shared compose file list for cxr-ops-lab (sourced by 04-compose-up/down, systemd).
set -euo pipefail

cxr_compose_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

cxr_compose_dc() {
  if command -v docker-compose &>/dev/null; then
    echo docker-compose
  elif docker compose version &>/dev/null 2>&1; then
    echo "docker compose"
  else
    echo "Need docker-compose or docker compose plugin" >&2
    return 1
  fi
}

# Sets: ROOT, COMPOSE_FILES (array), COMPOSE_MODE (host|bridge)
cxr_compose_files_init() {
  ROOT="$(cxr_compose_root)"
  COMPOSE_FILES=(-f "$ROOT/compose.yaml")
  local os
  os="$(docker info --format '{{.OperatingSystem}}' 2>/dev/null || true)"
  if grep -qi 'Docker Desktop' <<<"$os"; then
    COMPOSE_FILES+=(-f "$ROOT/compose.bridge.yaml")
    COMPOSE_MODE=bridge
  elif [[ "$(uname -s)" == "Linux" ]]; then
    COMPOSE_FILES+=(-f "$ROOT/compose.host.yaml")
    COMPOSE_MODE=host
  else
    COMPOSE_FILES+=(-f "$ROOT/compose.bridge.yaml")
    COMPOSE_MODE=bridge
  fi
}
