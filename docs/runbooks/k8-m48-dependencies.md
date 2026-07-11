# M4.8 — CXR on Kubernetes: dependency diagram

Bootcamp placement: pod runs **UI shell**; data plane stays on the host or Compose until you add in-cluster services.

```mermaid
flowchart LR
  subgraph kind [kind cxr-lab]
    Pod[cxr-ui Pod :3000]
    Svc[Service cxr-ui ClusterIP]
    Pod --> Svc
  end

  subgraph host [Host / Compose]
    SQL[SQL Server :1433]
    Qdrant[Qdrant :6333 or :6335]
    Analyze[Python analyzers via mounts]
  end

  User[Browser :8081 port-forward] --> Svc
  Dev8251[Rehearsal :8251] --> SQL
  Dev8251 --> Qdrant
  Dev8251 --> Analyze
  Compose3000[Compose :3000] --> SQL
  Compose3000 --> Qdrant
  Compose3000 --> Analyze
  Pod -.->|not wired in bootcamp| SQL
  Pod -.->|not wired in bootcamp| Qdrant
```

**Evidence path:** `helm/cxr-ui/` + `kubectl get all -n cxr-ui` + screenshot of http://localhost:8081.
