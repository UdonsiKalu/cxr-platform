#!/usr/bin/env bash
set -euo pipefail
NAME="${CXR_SW1_CONTAINER:-cxr-sw1-test}"
docker stop "$NAME" 2>/dev/null || true
docker rm "$NAME" 2>/dev/null || true
