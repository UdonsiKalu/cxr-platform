#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=../lib/cxr-paths.sh
source "$ROOT/scripts/lib/cxr-paths.sh"
cxr_paths_init
DOC="$(cxr_manual_doc_base "redis")"
MANUAL_DIR="$(dirname "$DOC")"
cd "$MANUAL_DIR"

if ! command -v pdflatex &>/dev/null; then
  echo "pdflatex not found. Install: sudo apt install texlive-latex-base texlive-latex-extra" >&2
  exit 1
fi

pdflatex -interaction=nonstopmode manual.tex >/dev/null || true
pdflatex -interaction=nonstopmode manual.tex >/dev/null || true

if [[ ! -f manual.pdf ]]; then
  echo "PDF build failed. Run pdflatex in $MANUAL_DIR for errors." >&2
  exit 1
fi
echo "Built: $DOC.pdf ($(wc -c < manual.pdf) bytes)"
