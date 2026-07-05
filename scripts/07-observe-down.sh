#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
# shellcheck source=lib/cxr-paths.sh
source "$ROOT/scripts/lib/cxr-paths.sh"
cxr_paths_init
if command -v docker-compose &>/dev/null; then
  docker-compose -f "$CXR_COMPOSE_OBSERVE" down "$@"
else
  docker compose -f "$CXR_COMPOSE_OBSERVE" down "$@"
fi
