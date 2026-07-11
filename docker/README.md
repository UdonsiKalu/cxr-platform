# Docker build contexts

| Path | Was | Image |
|------|-----|-------|
| `ui/Dockerfile` | `Dockerfile` | `cxr-ui:local` (K8 / SW.1) |
| `ui/Dockerfile.compose` | `Dockerfile.compose` | `cxr-ui:compose` (SW.2) |
| `analyzer/Dockerfile` | `Dockerfile.analyzer` | `cxr-analyzer:*` |

Root symlinks (`Dockerfile.analyzer`, etc.) preserve existing build scripts and CI paths.
