# CXR port map (probed 2026-05-26)

| Port | HTTP | Owner | Purpose |
|------|------|-------|---------|
| 8251 | 200 | rehearsal `next-server` (host) | **Main CXR UI** |
| 3000 | 200 | `cxr-ops-lab-cxr-ui-1` / `cxr-ui:compose` | SW.2 compose UI |
| 3002 | 200* | `cxr-sw1-test` / `cxr-ui:local` | SW.1 image (*when container running) |
| 3001 | 302 | `sandbox-grafana-1` | Grafana (not CXR UI) |
| 6333 | 200 | `sandbox-qdrant-1` | Dev Qdrant — `/dashboard` |
| 6335 | 200 | `cxr-ops-lab-qdrant-1` | Compose lab Qdrant — `/dashboard` |
| 8081 | 200 | kubectl → `cxr-ui` pod | SW.3 kind UI |
| 8181 | 404 | `sandbox-gateway-1` | Sandbox gateway API |
| 8281 | 200 | `sandbox-kernel-api-1` | Sandbox kernel API |
| 9091 | 302 | `sandbox-prometheus-1` | Sandbox Prometheus |
| 8080 | 301 | mailcow | Not CXR |

*3002 empty in browser = no container bound to port; run `docker run -p 3002:3000 cxr-ui:local`.
