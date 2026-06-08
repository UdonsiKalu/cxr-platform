#!/usr/bin/env bash
# Render Mermaid sources in docs/diagrams/ to PNG for LaTeX inclusion.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIAG="$ROOT/docs/diagrams"
MMDC=(npx -y @mermaid-js/mermaid-cli@11.4.0)
CONFIG="$DIAG/mermaid-config.json"
PUPPET="$DIAG/puppeteer-config.json"
SCALE=2

if ! command -v npx &>/dev/null; then
  echo "npx not found (need Node.js for mermaid-cli)." >&2
  exit 1
fi

render() {
  local mmd="$1" w="$2" h="$3"
  local base="${mmd%.mmd}"
  echo "Rendering $(basename "$mmd") (${w}x${h}, scale ${SCALE}) ..."
  "${MMDC[@]}" -p "$PUPPET" -c "$CONFIG" -i "$mmd" -o "${base}.png" \
    -b white -w "$w" -H "$h" -s "$SCALE"
}

mkdir -p "$DIAG"
shopt -s nullglob

# Portrait / tall diagrams
render "$DIAG/01-e2e-deployment-flow.mmd" 1100 1500
render "$DIAG/02-argo-object-graph.mmd" 900 1300
render "$DIAG/04-layered-deployment-model.mmd" 1200 1700

# Landscape / wide diagrams
render "$DIAG/03-m48-dependencies.mmd" 2000 1100
render "$DIAG/05-ci-vs-cd.mmd" 1800 700

echo "Diagram PNGs in $DIAG"
