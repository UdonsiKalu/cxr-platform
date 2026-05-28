# SW.9-11 observe verify (2026-05-27)

Branch A run in `cxr-ops-lab`:

- Started stack with `./scripts/07-observe-up.sh` (uses `compose.observe.yaml`).
- Containers started:
  - `cxr-ops-lab-prometheus-1` on `:9090`
  - `cxr-ops-lab-grafana-1` on `:3001`
- Health probes:
  - `GET http://localhost:9090/-/ready` -> `200` (`Prometheus Server is Ready.`)
  - `GET http://localhost:3001/api/health` -> `200` (`database: ok`, Grafana `11.2.0`)

Notes:

- Existing lab services remained up (`cxr-ops-lab-cxr-ui-1` on `:3000`, `cxr-ops-lab-qdrant-1` on `:6335`).
- `compose` reported these as orphans for the observe file, which is expected when running multiple compose profiles/files in the same project.
