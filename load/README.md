# CXR bootcamp load testing

Exercise **Claim Studio** and the observe stack under light concurrency. Electives (Kafka, Redis, GraphQL, …) are **not** hit unless you add custom scenarios.

## Tool comparison (for this lab)

| Tool | UI | Fits bootcamp | In repo |
|------|-----|---------------|---------|
| **Locust** | **Yes** — http://localhost:8089 | Python, easy `POST analyze`, live charts | **Yes** — `./scripts/22-load-locust.sh` |
| **k6** | CLI summary (Grafana Cloud optional) | Single binary, good for CI/scripts | **Yes** — `./scripts/22-load-k6.sh` |
| **JMeter** | Heavy GUI (.jmx) | Works; XML overhead for a small lab | Not bundled — export plan yourself |
| **Gatling** | Reports HTML | Works; Scala/Java build step | Not bundled — use if you already know it |

**Recommendation:** start with **Locust** (watch RPS/latency in the browser), then **k6** for a repeatable one-liner or future CI.

## Before load

```bash
cd cxr-ops-lab
./scripts/07-observe-up.sh          # Jaeger :16686, Grafana :3001
./scripts/04-compose-up.sh          # CXR :3000 (or use :8251 rehearsal)
# optional logs during load:
./scripts/16-elk-up.sh
```

For traces on **:8251**, run rehearsal with `OTEL_*` (see `.env.otel.example`).

## Locust (web UI)

```bash
# default target http://127.0.0.1:3000
./scripts/22-load-locust.sh

# or rehearsal
CXR_LOAD_URL=http://127.0.0.1:8251 ./scripts/22-load-locust.sh
```

1. Open **http://localhost:8089**
2. Set **Number of users** (start **3–5**) and **Spawn rate** (**1**/s)
3. Click **Start swarming**
4. During run: **Jaeger** http://localhost:16686 · **Grafana** http://localhost:3001 · **Solutions** nav on CXR UI

`analyze` is slow (~5–15s); do **not** start with 50+ users on one machine.

## k6 (CLI)

Install: https://grafana.com/docs/k6/latest/set-up/install-k6/  
(e.g. `sudo gpg ...` or `snap install k6`)

```bash
./scripts/22-load-k6.sh
# tune:
K6_VUS=3 K6_DURATION=2m CXR_LOAD_URL=http://127.0.0.1:3000 ./scripts/22-load-k6.sh
```

## JMeter / Gatling (bring your own)

Point at the same endpoint:

```http
POST /api/claim-studio/analyze
Content-Type: application/json

{"input":{"content":"{\"claim_id\":\"load-1\",\"description\":\"office visit\"}"}}
```

Base URL: `http://localhost:3000` or `http://localhost:8251`.

## While load runs

| Pillar | URL |
|--------|-----|
| Traces | http://localhost:16686 |
| Metrics | http://localhost:3001 |
| Logs (:3000 only) | http://localhost:5601 |

Map: **http://localhost:8251/solutions-atlas** → wiring matrix.
