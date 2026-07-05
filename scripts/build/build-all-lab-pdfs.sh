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
DOC="$ROOT/docs/CXR-BOOTCAMP-LABS-COMPENDIUM"
cd "$ROOT/docs"
pdflatex -interaction=nonstopmode "$(basename "$DOC").tex" >/dev/null || true
pdflatex -interaction=nonstopmode "$(basename "$DOC").tex" >/dev/null || true
[[ -f "$DOC.pdf" ]] || { echo "Compendium PDF build failed." >&2; exit 1; }
echo "Built: $DOC.pdf ($(wc -c < "$DOC.pdf") bytes)"

echo ""
echo "All lab PDFs in $ROOT/docs/:"
ls -1 "$ROOT/docs"/CXR-*-MANUAL.pdf "$ROOT/docs"/CXR-BOOTCAMP-LABS-COMPENDIUM.pdf 2>/dev/null | sort
