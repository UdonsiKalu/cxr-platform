# Compose vs full CXR (:8251) — coverage matrix

**Lab stack:** `./scripts/04-compose-up.sh` → `compose/core/compose.yaml` + `compose/core/host.yaml` (Linux).

| Capability | :8251 dev | Compose :3000 | Notes |
|------------|-----------|---------------|--------|
| Next.js UI | host `npm run dev` | `cxr-ui:compose` | Same rehearsal build |
| Claim Studio **analyze** | yes | yes | `/analyzers` mount + ODBC + host SQL/Qdrant |
| Claim Studio **audit/start** (judge) | yes | yes* | `CXR_JUDGE_SCRIPT` + `ollama` pip; needs **host Ollama** :11434 |
| Terminal / `lib/db` SQL routes | yes | yes* | `CXR_SQL_*` via `.env.compose.local` |
| Qdrant (doc-reasoning, policies) | host :6333 | host :6333 | Host overlay; sidecar :6335 is optional/empty |
| Sample claims `/claims/samples` | yes | yes | `CXR_EXAMPLES_FOLDER=/analyzers/examples` |
| Atlas `/atlas` source drill-down | yes | partial | Needs `/staging` mount + `CXR_ATLAS_*` |
| Platform docs `/api/docs` | yes | partial | `CXR_DOCS_LIBRARY_ROOT` on `/staging` mount |
| Sandbox gateway :8181 | optional | optional | `CXR_GATEWAY_URL` — host service |
| Kernel API :8281 | optional | optional | `CXR_API_BASE` — host service |
| Grafana/Prometheus/Kafka | sandbox | not in SW.2 | Use `compose/observe/compose.yaml` / `compose/labs/kafka.yaml` |
| Production `cxrlabs-dev/platform/infra` | prod | **not used** | Bootcamp uses `cxr-ops-lab` only |

\* Requires `.env.compose.local` (copy from `.env.compose.example`, align with `.env.local`).

## Intentionally not in compose (use host or later SW)

- Full `sentence-transformers` / GPU embedder in container (heavy; kernel runs without or warns)
- Duplicating prod K8s/Helm from `cxrlabs-dev/platform/infra`
- Mailcow, Jitsi, unrelated host containers

## Files

| File | Role |
|------|------|
| `compose/core/compose.yaml` | UI + env + analyzers mount + writable `data/` |
| `compose/core/host.yaml` | Linux: `network_mode: host`, host URLs, `/staging` ro mount |
| `compose/core/bridge.yaml` | Optional: no host network (`host.docker.internal`) |
| `.env.compose.local` | Secrets + SQL (gitignored) |
| `docker/ui/Dockerfile.compose` | python3, ODBC 17, pyodbc, qdrant-client, ollama |
