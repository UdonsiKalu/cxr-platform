# CXR Vault Lab Manual (SW.17)

**PDF:** `docs/CXR-VAULT-LAB-MANUAL.pdf` — `./scripts/build-vault-manual-pdf.sh`  
**Syllabus:** SW.17 — Vault dev + CXR secret map (M4.3 / M6.7)  
**Date:** 2026-05-31

## How this is wired (step by step)

1. **`./scripts/20-vault-up.sh`** → `docker compose -f compose.vault.yaml up -d`
2. **`compose.vault.yaml`** starts `hashicorp/vault:1.17` on **:8200**, dev token **`cxr-bootcamp-root`**
3. **`./scripts/20-vault-smoke.sh`** → health check → **`lab/vault/seed-cxr-secrets.sh`**
4. **Seed script** `docker exec`s into the container and runs `vault kv put secret/cxr/...`
5. **Browser** http://localhost:8200 → Token login → **Secrets** → `secret/cxr/analyzer`

**Not wired today:** Claim Studio `:3000` still reads `.env` / compose env — not Vault yet.

**Future sketch:** K8 External Secrets → Vault paths → pod env on `:8081`.

## Quick start

```bash
cd cxr-ops-lab
./scripts/20-vault-up.sh
./scripts/20-vault-smoke.sh
```

## UI after login

- **Ignore:** Dashboard, Access, Agents (production topics)
- **Open:** Secrets → `secret/` → `cxr/` → **`analyzer`** (golden path)

## Secret map

| Vault path | CXR env keys |
|------------|----------------|
| `secret/cxr/analyzer` | `CXR_ANALYZER_SCRIPT`, `CXR_JUDGE_SCRIPT` |
| `secret/cxr/otel` | `OTEL_*` |
| `secret/cxr/datastores` | `QDRANT_URL`, `DATABASE_URL` |

Source: `lab/vault/cxr-secret-map.json`

## Files

| Path | Role in wiring |
|------|----------------|
| `compose.vault.yaml` | Vault service + dev token |
| `lab/vault/seed-cxr-secrets.sh` | Writes KV secrets |
| `scripts/20-vault-up.sh` / `20-vault-smoke.sh` | Start + verify |

## Stop

```bash
docker compose -f compose.vault.yaml down
```

## Master wiring doc

Full bootcamp connection map: **`docs/CXR-BOOTCAMP-LABS-COMPENDIUM.pdf`** (chapter 1).
