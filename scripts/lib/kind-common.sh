#!/usr/bin/env bash
# Back-compat shim — prefer scripts/lib/k8-common.sh (Docker Desktop K8 + kind).
# shellcheck source=lib/k8-common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/k8-common.sh"
