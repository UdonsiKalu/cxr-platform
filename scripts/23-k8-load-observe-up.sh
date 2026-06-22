#!/usr/bin/env bash
# OBS-001 live: Prometheus + Grafana + Jaeger + load metrics for K8 load tests.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/bin:${PATH:-}"
# shellcheck source=lib/kind-common.sh
source "$ROOT/scripts/lib/kind-common.sh"

require_kubectl "$ROOT"
echo "Cluster: $(kubectl config current-context) ($(cxr_k8_runtime))"

"$ROOT/scripts/07-observe-up.sh"
"$ROOT/scripts/09-metrics-server-install.sh"
"$ROOT/scripts/10-kube-state-metrics-install.sh"
"$ROOT/scripts/k8-ksm-port-forward.sh" start
"$ROOT/scripts/k8-load-exporter.sh" start
"$ROOT/scripts/k8-analyzer-metrics-forward.sh" start

# Reload Prometheus config (new scrape jobs / after observe restart)
if command -v docker &>/dev/null; then
  docker compose -f "$ROOT/compose.observe.yaml" restart prometheus 2>/dev/null \
    || docker-compose -f "$ROOT/compose.observe.yaml" restart prometheus 2>/dev/null \
    || true
fi

echo ""
echo "== CXR K8 load observe stack =="
echo "  Grafana LOAD-003:    http://127.0.0.1:3001/d/cxr-hpa-load-003"
echo "  Prometheus targets:  http://127.0.0.1:9090/targets"
echo "  Jaeger (traces):     http://127.0.0.1:16686  → service cxr-analyzer-service"
echo "  Load exporter:       http://127.0.0.1:9102/metrics"
echo "  Analyzer metrics:    http://127.0.0.1:8767/metrics  (port-forward)"
echo "  KSM metrics:         http://127.0.0.1:9091/metrics"
echo ""
echo "Verify targets cxr-load-exporter + kube-state-metrics + cxr-analyzer are UP, then run Locust :8092."
echo "Runbook: docs/K8-LOAD-OBSERVE-RUNBOOK.md"
