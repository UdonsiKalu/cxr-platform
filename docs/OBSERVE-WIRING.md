# Observe stack — two YAML files (why both exist)

| File | Role |
|------|------|
| **`compose.observe.yaml`** | **Docker Compose** — starts/stops containers (Prometheus, Grafana), ports, restart policy, named volumes for persistence |
| **`observe/prometheus.yml`** | **Prometheus config** — what to scrape (jobs, targets, paths). Mounted *into* the Prometheus container at `/etc/prometheus/prometheus.yml` |

Grafana wiring is also in **`compose.observe.yaml`** (image, port **3001**, password env, volume mounts).  
Grafana datasource/dashboard **provisioning** lives under **`observe/grafana/provisioning/`** (not a second compose file).

## Connection to rehearsal

- **Not** wired inside `cxr-ui-rehearsal` GitHub CI workflow.
- **Runtime link:** Prometheus scrapes a **running** app URL (e.g. `host.docker.internal:3000` from compose lab), configured in `prometheus.yml`.
- Daily rehearsal dev (**:8251**) is separate unless you add a scrape target for it.

## Persistence (reboot / Cursor / browser)

- **Browser/Cursor restart** does not stop Grafana — only closing Docker or stopping the observe stack does.
- **Named volumes:** `grafana_data`, `prometheus_data` keep DB + metrics across container recreate.
- **systemd:** `cxr-observe.service` + `cxr-lab.target` auto-start observe with other lab ports.

```bash
cd cxr-ops-lab
./scripts/09-enable-persistent-ports.sh   # installs cxr-observe.service
# or one-off:
./scripts/07-observe-up.sh
```

Grafana: http://localhost:3001 — login persists in `grafana_data` volume.
