# Compose layouts

Docker Compose files grouped by purpose. Scripts reference these via `scripts/lib/cxr-paths.sh`.

| Path | Purpose |
|------|---------|
| `core/compose.yaml` | SW.2 UI + Qdrant |
| `core/host.yaml` | Linux host-network overlay |
| `core/bridge.yaml` | Docker Desktop overlay |
| `observe/compose.yaml` | Prometheus, Grafana, Jaeger, OTEL |
| `observe/otel-link.yaml` | Link cxr-ui to observe network |
| `labs/*.yaml` | Bootcamp SW.12–18 standalone labs |

Volume paths in these files use `../../` to reach repo root (`observe/`, `.env.compose.local`, etc.).

Example:

```bash
docker compose -f compose/observe/compose.yaml up -d
./scripts/07-observe-up.sh   # same stack
```
