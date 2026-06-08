# SW.18 Langfuse verify — 2026-05-31

- Timestamp: 2026-05-31T08:43-05:00
- Stack: `./scripts/21-langfuse-up.sh`
- Smoke: `./scripts/21-langfuse-smoke.sh`

## Checklist

- [x] Langfuse **:3100** up (not CXR **:3000**) — agent smoke HTTP 200
- [ ] User signup + project + API keys → `lab/langfuse/keys.env`
- [ ] Trace **`cxr-sw18-golden-path`** visible in UI
- [ ] Optional screenshot → `evidence/SW18-langfuse-traces-2026-05-31.png`
- [x] Manual PDF → `docs/CXR-LANGFUSE-LAB-MANUAL.pdf`

## CXR placement (M7.8 / SW.18)

Maps Langfuse **project** to doc-reasoning / judge LLM calls (hypothetical — not wired to Claim Studio routes yet).

## Stop

```bash
docker compose -f compose.langfuse.yaml down
```
