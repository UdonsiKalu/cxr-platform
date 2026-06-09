#!/usr/bin/env bash
# OBS-001 live: Prometheus + Grafana + Jaeger + kube-state-metrics for K8 load tests.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/bin:${PATH:-}"
# shellcheck source=lib/kind-common.sh
source "$ROOT/scripts/lib/kind-common.sh"

require_kubectl "$ROOT"
echo "Cluster: $(kubectl config current-context) ($(cxr_k8_runtime))"

"$ROOT/scripts/07-observe-up.sh"
"$ROOT/scripts/10-kube-state-metrics-install.sh"
"$ROOT/scripts/k8-ksm-port-forward.sh" start

echo ""
echo "== CXR K8 load observe stack =="
echo "  Grafana (live HPA):  http://127.0.0.1:3001/d/cxr-hpa-load-003"
echo "  Prometheus:          http://127.0.0.1:9090/targets  (job kube-state-metrics)"
echo "  Jaeger (traces):     http://127.0.0.1:16686  → service cxr-analyzer-service"
echo "  KSM metrics:         http://127.0.0.1:9091/metrics"
echo ""
echo "Verify Prometheus target 'kube-state-metrics' is UP, then run Locust."
echo "Runbook: docs/K8-LOAD-OBSERVE-RUNBOOK.md"
