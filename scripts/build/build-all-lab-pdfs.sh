#!/usr/bin/env bash
# Build all CXR bootcamp lab PDFs (individual manuals + compendium).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

build() {
  local script="$1"
  echo "== $script =="
  "$ROOT/scripts/$script"
}

for s in build-otel-manual-pdf.sh build-elk-manual-pdf.sh build-kafka-manual-pdf.sh \
  build-redis-manual-pdf.sh build-graphql-manual-pdf.sh build-grpc-manual-pdf.sh \
  build-vault-manual-pdf.sh build-langfuse-manual-pdf.sh build-k8-manual-pdf.sh; do
  if [[ -x "$ROOT/scripts/$s" ]]; then
    build "$s"
  fi
done

echo "== build-bootcamp-compendium-pdf.sh =="
# shellcheck source=lib/cxr-paths.sh
source "$ROOT/scripts/lib/cxr-paths.sh"
cxr_paths_init
DOC="$(cxr_manual_doc_base compendium)"
MANUAL_DIR="$(dirname "$DOC")"
cd "$MANUAL_DIR"
pdflatex -interaction=nonstopmode manual.tex >/dev/null || true
pdflatex -interaction=nonstopmode manual.tex >/dev/null || true
[[ -f manual.pdf ]] || { echo "Compendium PDF build failed." >&2; exit 1; }
echo "Built: $DOC.pdf ($(wc -c < manual.pdf) bytes)"

echo ""
echo "All lab PDFs under $ROOT/docs/manuals/:"
find "$ROOT/docs/manuals" -name 'manual.pdf' | sort
