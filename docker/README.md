# Docker build contexts

| Path | Image |
|------|-------|
| `ui/Dockerfile` | `cxr-ui:local` (K8 / SW.1) |
| `ui/Dockerfile.compose` | `cxr-ui:compose` (SW.2) |
| `analyzer/Dockerfile` | `cxr-analyzer:*` |

Requirements files: `ui/requirements.txt`, `analyzer/requirements.txt`.

Build scripts and CI use these paths directly (see `scripts/lib/cxr-paths.sh`).
