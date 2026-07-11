# Compose layouts

Docker Compose files grouped by purpose. **Root symlinks** (`compose.observe.yaml`, etc.) point here for backward compatibility.

| Path | Was | Purpose |
|------|-----|---------|
| `core/compose.yaml` | `compose.yaml` | SW.2 UI + Qdrant |
| `core/host.yaml` | `compose.host.yaml` | Linux host-network overlay |
| `core/bridge.yaml` | `compose.bridge.yaml` | Docker Desktop overlay |
| `observe/compose.yaml` | `compose.observe.yaml` | Prometheus, Grafana, Jaeger, OTEL |
| `observe/otel-link.yaml` | `compose.otel-link.yaml` | Link cxr-ui to observe network |
| `labs/*.yaml` | `compose.*.yaml` | Bootcamp SW.12–18 standalone labs |

Volume paths in these files use `../../` to reach repo root (`observe/`, `.env.compose.local`, etc.).
