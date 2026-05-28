# Platform engineering vs CXR rehearsal — syllabus map

From `CXR-Syllabus-Case-Study-Study-Plan.md` **SW.1–SW.18**. This is **what each tool is for** and **where you are**.

| SW | Tool | Role in CXR case study | Your status |
|----|------|------------------------|-------------|
| **SW.1** | Docker | Package **rehearsal `cxr-ui`** | Done — `cxr-ops-lab/Dockerfile`, image `cxr-ui:local` |
| **SW.2** | Docker Compose | **UI + Qdrant** (+ mount analyzers) | **Run** — `compose.yaml` + `04-compose-up.sh` |
| **SW.3** | Kubernetes (`kind`) | Run same image in cluster | Done — `03-k8-up.sh` / `12-k8-ensure.sh`, `:8081` forward |
| **SW.4** | Helm | Package SW.3 manifests + values | Done — `helm/cxr-ui`, `05-helm-install.sh` |
| **SW.5** | Terraform | Provision `kind` cluster | Scaffold — `terraform/` + ADR (run `terraform apply` locally) |
| **SW.6** | GitHub Actions CI | `npm ci` / build on push | Done — `cxr-ui-rehearsal` CI |
| **SW.6a** | Playwright | E2E in CI | Done — in canonical CI workflow |
| **SW.7** | Trivy | Scan image in CI | Done — CI + local `08-trivy-scan.sh` |
| **SW.8** | Argo CD | GitOps Helm chart | Scaffold — `13-argo-install.sh` (needs `CXR_ARGO_REPO_URL`) |
| **SW.9** | Prometheus | Scrape HTTP metrics | After app runs in K8/compose |
| **SW.10** | Grafana | Dashboards on Prometheus | With SW.9 |
| **SW.11** | OpenTelemetry | Trace browser → API → Qdrant/DB | With SW.9; ties **M1.6** |
| **SW.12** | ELK | Log shipping (optional) | Optional / skip with ADR |
| **SW.13** | **Kafka** or RabbitMQ | **Async events** (claim submitted, audit done) | **Lab only** — not in current CXR UI path; relates **M5.4** messaging |
| **SW.14** | Redis | Cache-aside for hot reads | Lab — optional for policy/artifact cache |
| **SW.15** | GraphQL gateway | Syllabus **lab** pattern (Apollo + mocks) | Not prod CXR REST spine |
| **SW.16** | gRPC | Internal RPC sketch vs `platform/` | Read-only unless you add hello server |
| **SW.17** | Vault + K8s secrets | Map **M4.3** env to secrets | After SW.3–4 |
| **SW.18** | Langfuse | LLM trace + eval | After you have an LLM call path |

## Two paths in the syllabus

1. **Comprehensive table order** — K8 early (SW.3), then Helm, Terraform, CI, … then Kafka/Redis (SW.13–14).  
2. **Starter ten milestones** — Dockerfile → Compose → **CI → Trivy → Playwright → metrics → OTel** → then K8 → Helm → Terraform; **Kafka/Argo/Vault/Langfuse after milestone 10**.

You did **Starter #8 (K8)** before **#2 (Compose)** — fine. Next logical fill-ins: **SW.2 compose** (this repo), **SW.3 evidence**, then either **Starter #3 CI** or **SW.4 Helm**.

## How Kafka fits (not running yet)

CXR today is **sync HTTP**: UI `fetch` → Next `route.ts` → `spawn` Python.

**Kafka would sit beside that**, not replace it, for example:

- Producer: after `analyze` returns, publish `claim.analyzed` JSON to topic `cxr.claims.events`
- Consumer: audit worker, metrics indexer, or downstream billing (M5.4)

**Lab (SW.13):** add `kafka` + `zookeeper` (or Redpanda) to a **separate** `compose.kafka.yaml` in `cxr-ops-lab`; CLI producer sends one JSON; consumer logs it. **No change** to rehearsal UI until you deliberately add a publisher in a route.

## How this differs from “original CXR”

| Stack | Path | Uses |
|-------|------|------|
| **Rehearsal + ops-lab** | `cxr-ui-prune-rehearsal`, `cxr-ops-lab` | Bootcamp Docker/K8/Compose |
| **Production platform** | `cxrlabs-dev/.../platform/infra` | gateway, analysis service, Prometheus — **unchanged** |

Do not confuse **kind CXR UI pod** with **production gateway compose**.

## Suggested order from here

1. **SW.2** — `./scripts/04-compose-up.sh` → test Claim Studio on `:3000`  
2. **SW.3 evidence** — screenshot `kubectl get all -n cxr-ui`  
3. **SW.6 + SW.7** — CI build + Trivy (rehearsal GitHub repo)  
4. **SW.4** — Helm chart wrapping `deploy/k8s/`  
5. **SW.13** — Kafka compose lab (standalone)  
6. **SW.9–11** — Prometheus/Grafana/OTel on whichever runtime you keep (compose or K8)
