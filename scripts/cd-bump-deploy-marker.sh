#!/usr/bin/env bash
# Local CD-001 dry-run: bump gitOpsDeployMarker so Argo syncs after git push.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MARKER="${1:-local-$(date +%Y%m%d-%H%M%S)}"
for f in "$ROOT/helm/cxr-analyzer/values.yaml" "$ROOT/helm/cxr-ui/values.yaml"; do
  sed -i "s/^gitOpsDeployMarker:.*/gitOpsDeployMarker: \"${MARKER}\"/" "$f"
done
echo "Bumped gitOpsDeployMarker to: $MARKER"
echo "Next: git commit + push → Argo CD syncs"
