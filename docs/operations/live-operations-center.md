# CXR Live Operations Center

Operational-readiness dashboard for the CXR stack. **All metrics come from synthetic traffic** against the local analyze API — not customer production workloads.

## What this is

| Layer | URL | Role |
|-------|-----|------|
| **Website embed** | http://localhost:8251/live-ops | Read-only Grafana panel iframes under CXR Labs nav |
| **Full dashboard** | http://localhost:3001/d/cxr-live-ops/cxr-live-operations-center | Grafana **CXR Live Operations Center** |
| **Metrics source** | http://localhost:9103/metrics | `synthetic_*` Prometheus metrics |
| **Traces** | http://localhost:16686 | Jaeger — search `cxr-ui-rehearsal` + analyze spans |

Dashboard JSON (provisioned + export):

- `observe/grafana/provisioning/dashboards/cxr-live-operations-center.json`
- `docs/observability/grafana/cxr-live-operations-center.json`

## Local quick start

```bash
# 1) Observe stack (Prometheus, Grafana, Jaeger, OTel)
cd ~/staging/cxr-ops-lab && ./scripts/07-observe-up.sh

# 2) Dev stack — rehearsal :8251 + analyzer :8766 (if not already systemd)
~/staging/cxr-dev.sh up
# Or: systemctl --user start cxr-rehearsal-dev + start analyzer manually

# 3) Synthetic readiness traffic → :8251 analyze
./scripts/25-synthetic-readiness-up.sh start

# 4) Reload Prometheus after first-time config changes; recreate Grafana if embed env changed
docker compose -f compose.observe.yaml restart prometheus
docker compose -f compose.observe.yaml up -d --force-recreate grafana

# 5) Open
#    http://localhost:8251/live-ops
#    http://localhost:3001/d/cxr-live-ops/cxr-live-operations-center
#    http://localhost:16686
```

Check synthetic metrics:

```bash
./scripts/25-synthetic-readiness-up.sh status
curl -s http://127.0.0.1:9103/metrics | grep '^synthetic_'
```

## Synthetic metrics

| Metric | Type | Description |
|--------|------|-------------|
| `synthetic_requests_total` | Counter | Analyze requests by `profile`, `method`, `status` |
| `synthetic_failures_total` | Counter | Failures by `profile`, `reason` |
| `synthetic_active_users` | Gauge | Concurrent synthetic workers |
| `synthetic_profile` | Gauge | Profile marker (`operational_readiness`) |
| `synthetic_request_latency_seconds` | Histogram | End-to-end analyze latency |

Recording rules (`cxr_synthetic_*`) in `observe/prometheus/cxr_recording_rules.yml`.

## Security

- **Read-only public view:** Grafana anonymous **Viewer** + solo-panel embeds only on `/live-ops`.
- **No admin Grafana exposure** on public routes — do not tunnel admin login to the internet.
- **No secrets** in this repo — tunnel tokens and API keys stay local.
- **No PHI** — synthetic claim IDs and descriptions only.
- **Not production traffic** — label shown on dashboard and website.

## Future: udonsik.com via Cloudflare Tunnel

When migrating from localhost:

1. Run `cloudflared` with a **read-only** Grafana viewer hostname (example: `ops.{YOUR_DOMAIN}`).
2. Set `NEXT_PUBLIC_GRAFANA_URL` on the Next.js app to that hostname.
3. Keep **admin** Grafana on localhost or a separate locked-down origin — not on the public tunnel.
4. Example ingress shape (placeholders only — **do not commit** real IDs or tokens):

```yaml
# ~/.cloudflared/config.yml (local only — not in git)
ingress:
  - hostname: ops.{YOUR_DOMAIN}
    service: http://127.0.0.1:3001
  - service: http_status:404
```

5. Use Cloudflare Access or Grafana anonymous Viewer; never expose `GF_SECURITY_ADMIN_PASSWORD` via tunnel.

## Related

- [OBSERVE-WIRING.md](../OBSERVE-WIRING.md)
- [cxr-portfolio/reliability/SLO.md](../../../cxr-portfolio/reliability/SLO.md)
