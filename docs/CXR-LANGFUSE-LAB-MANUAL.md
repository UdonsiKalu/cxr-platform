# CXR Langfuse Lab Manual (SW.18)

**PDF:** `docs/CXR-LANGFUSE-LAB-MANUAL.pdf` — `./scripts/build-langfuse-manual-pdf.sh`  
**Syllabus:** SW.18 — LLM trace + eval (M7.8)  
**Date:** 2026-05-31

## What this lab adds

**Langfuse v2** (Postgres only — lightweight bootcamp stack). Port **3100** avoids CXR Claim Studio **:3000**.

| URL | Role |
|-----|------|
| **http://localhost:3100** | Langfuse UI — traces, evals |

## Wiring chain

```
21-langfuse-up.sh → compose.langfuse.yaml → :3100 UI signup
→ Settings → API Keys → lab/langfuse/keys.env → send-trace.mjs
→ Tracing → Traces → cxr-sw18-golden-path
```

Claim Studio **:3000** is **not connected** yet (future judge/analyzer spans).

## Quick start

```bash
cd cxr-ops-lab
./scripts/21-langfuse-up.sh
# Sign up → org → project → Settings → API Keys
cp lab/langfuse/keys.env.example lab/langfuse/keys.env   # uncomment + paste keys
node lab/langfuse/send-trace.mjs
./scripts/21-langfuse-smoke.sh
```

Golden trace name: **`cxr-sw18-golden-path`**

## keys.env (must be uncommented)

```bash
LANGFUSE_HOST=http://127.0.0.1:3100
LANGFUSE_PUBLIC_KEY=pk-lf-...
LANGFUSE_SECRET_KEY=sk-lf-...
```

## Files

| Path | Role |
|------|------|
| `compose.langfuse.yaml` | Langfuse v2 + Postgres |
| `lab/langfuse/send-trace.mjs` | Demo trace + generation |
| `lab/langfuse/keys.env.example` | API key template |
| `scripts/21-langfuse-up.sh` / `21-langfuse-smoke.sh` | Start + verify |

## Stop

```bash
docker compose -f compose.langfuse.yaml down
```

## Related

- Master wiring: `docs/CXR-BOOTCAMP-LABS-COMPENDIUM.pdf`
- SW.12–SW.18 electives complete in `cxr-ops-lab`
