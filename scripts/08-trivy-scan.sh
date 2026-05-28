#!/usr/bin/env bash
# SW.7 — scan a local Docker image with Trivy (bootcamp; no GitHub required)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="${1:-cxr-ui:compose}"
TRIVY="${TRIVY_BIN:-$HOME/.local/bin/trivy}"

if ! command -v docker &>/dev/null; then
  echo "docker required" >&2
  exit 1
fi
if [[ ! -x "$TRIVY" ]] && ! command -v trivy &>/dev/null; then
  echo "Installing Trivy to $HOME/.local/bin ..."
  mkdir -p "$HOME/.local/bin"
  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b "$HOME/.local/bin"
fi
TRIVY="$(command -v trivy || echo "$TRIVY")"

if ! docker image inspect "$IMAGE" &>/dev/null; then
  echo "Image not found: $IMAGE" >&2
  echo "Build first: $ROOT/scripts/04-compose-up.sh  (cxr-ui:compose) or 02-build-and-load.sh (cxr-ui:local)" >&2
  exit 1
fi

echo "Trivy $( "$TRIVY" --version | head -1 ) on $IMAGE (HIGH, CRITICAL)"
"$TRIVY" image --severity HIGH,CRITICAL --format table "$IMAGE"
echo ""
echo "Full report: $TRIVY image --format json -o $ROOT/evidence/trivy-${IMAGE//[:\/]/-}.json $IMAGE"
