#!/usr/bin/env bash
# Build docs/CXR-ELK-LAB-MANUAL.pdf from LaTeX source.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
DOC="$ROOT/docs/CXR-ELK-LAB-MANUAL"
cd "$ROOT/docs"

if ! command -v pdflatex &>/dev/null; then
  echo "pdflatex not found. Install: sudo apt install texlive-latex-base texlive-latex-extra" >&2
  exit 1
fi

pdflatex -interaction=nonstopmode "$(basename "$DOC").tex" >/dev/null || true
pdflatex -interaction=nonstopmode "$(basename "$DOC").tex" >/dev/null || true

if [[ ! -f "$DOC.pdf" ]]; then
  echo "PDF build failed." >&2
  exit 1
fi
echo "Built: $DOC.pdf ($(wc -c < "$DOC.pdf") bytes)"
