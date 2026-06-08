#!/usr/bin/env bash
# Build docs/CXR-K8-DEPLOYMENT-MANUAL.pdf from LaTeX source (original TikZ layout).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOC="$ROOT/docs/CXR-K8-DEPLOYMENT-MANUAL"
cd "$ROOT/docs"

if ! command -v pdflatex &>/dev/null; then
  echo "pdflatex not found. Install: sudo apt install texlive-latex-base texlive-latex-extra" >&2
  exit 1
fi

pdflatex -interaction=nonstopmode "$(basename "$DOC").tex" >/dev/null || true
pdflatex -interaction=nonstopmode "$(basename "$DOC").tex" >/dev/null || true

if [[ ! -f "$DOC.pdf" ]]; then
  echo "PDF build failed. Run pdflatex in docs/ for errors." >&2
  exit 1
fi
echo "Built: $DOC.pdf ($(wc -c < "$DOC.pdf") bytes, $(pdfinfo "$DOC.pdf" 2>/dev/null | awk '/Pages:/ {print $2}') pages)"
