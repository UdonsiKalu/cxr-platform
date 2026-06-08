#!/usr/bin/env bash
# SW.18 — Start Langfuse v2 + Postgres.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if command -v docker-compose &>/dev/null; then
  DC=(docker-compose)
else
  DC=(docker compose)
fi
"${DC[@]}" -f compose.langfuse.yaml up -d
echo ""
echo "Langfuse UI:   http://localhost:3100  (not CXR :3000)"
echo "First visit:   sign up → create project → API Keys → lab/langfuse/keys.env"
echo ""
echo "Send trace:    node lab/langfuse/send-trace.mjs  (after keys.env)"
echo "Smoke test:    ./scripts/21-langfuse-smoke.sh"
echo "Evidence:      evidence/SW18-langfuse-verify-2026-05-31.md"
echo "Manual:        docs/CXR-LANGFUSE-LAB-MANUAL.pdf (./scripts/build-langfuse-manual-pdf.sh)"
