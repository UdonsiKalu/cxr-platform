#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=compose-files.sh
source "$(dirname "$0")/compose-files.sh"
cxr_compose_files_init
DC=($(cxr_compose_dc))
cd "$ROOT"
PROFILE_ARGS=()
if [[ "${CXR_COMPOSE_QDRANT:-}" == "1" ]]; then
  PROFILE_ARGS=(--profile with-lab-qdrant)
fi
echo "Stopping cxr-ops-lab ($COMPOSE_MODE overlay)..."
"${DC[@]}" "${COMPOSE_FILES[@]}" "${PROFILE_ARGS[@]}" down "$@"
