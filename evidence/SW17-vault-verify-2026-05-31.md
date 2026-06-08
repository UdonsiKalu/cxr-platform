# SW.17 Vault verify — 2026-05-31

- Timestamp: 2026-05-31T08:42-05:00
- Stack: `./scripts/20-vault-up.sh`
- Smoke: `./scripts/20-vault-smoke.sh`

## Checklist

- [x] Vault **:8200** up — dev mode, token `cxr-bootcamp-root` (agent smoke)
- [x] `secret/cxr/analyzer` seeded — `CXR_ANALYZER_SCRIPT=/analyzers/analyze_sample.py`
- [ ] Optional UI screenshot → `evidence/SW17-vault-ui-2026-05-31.png`
- [x] Manual PDF → `docs/CXR-VAULT-LAB-MANUAL.pdf`

## CXR placement (M6.7 / SW.17)

| Today | With Vault (hypothetical) |
|-------|---------------------------|
| `.env.local` / compose env files | `secret/cxr/*` paths; K8 **External Secrets** sync to pod env |
| Secrets in git (forbidden) | Vault paths in `lab/vault/cxr-secret-map.json` only |

## Stop

```bash
docker compose -f compose.vault.yaml down
```
