#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOC="$ROOT/docs/CXR-VAULT-LAB-MANUAL"
cd "$ROOT/docs"
pdflatex -interaction=nonstopmode "$(basename "$DOC").tex" >/dev/null || true
pdflatex -interaction=nonstopmode "$(basename "$DOC").tex" >/dev/null || true
[[ -f "$DOC.pdf" ]] || { echo "PDF build failed." >&2; exit 1; }
echo "Built: $DOC.pdf ($(wc -c < "$DOC.pdf") bytes)"
