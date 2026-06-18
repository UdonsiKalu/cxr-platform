#!/usr/bin/env python3
"""Poll Locust + kubectl → Prometheus metrics for LOAD-003 Grafana dashboard."""

from __future__ import annotations

import os
import sys
import time
from pathlib import Path

from prometheus_client import Gauge, start_http_server

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
from lib.load_metrics_poll import collect_row  # noqa: E402

NAMESPACE = os.environ.get("CXR_K8_NAMESPACE", "cxr-ui")
LOCUST_URL = os.environ.get("CXR_LOCUST_URL", "http://127.0.0.1:8092")
POLL_INTERVAL = float(os.environ.get("CXR_LOAD_EXPORTER_INTERVAL", "5"))
PORT = int(os.environ.get("CXR_LOAD_EXPORTER_PORT", "9102"))

G = {
    "locust_users": Gauge("cxr_locust_users", "Locust simulated users"),
    "locust_rps": Gauge("cxr_locust_rps", "Locust requests per second"),
    "locust_failures_per_second": Gauge(
        "cxr_locust_failures_per_second", "Locust failures per second"
    ),
    "locust_p50_ms": Gauge("cxr_locust_p50_ms", "Locust median response time (ms)"),
    "locust_p95_ms": Gauge("cxr_locust_p95_ms", "Locust p95 response time (ms)"),
    "hpa_analyzer_current_cpu_percent": Gauge(
        "cxr_hpa_analyzer_current_cpu_percent", "Analyzer HPA current CPU %"
    ),
    "hpa_analyzer_target_cpu_percent": Gauge(
        "cxr_hpa_analyzer_target_cpu_percent", "Analyzer HPA target CPU %"
    ),
    "hpa_ui_current_cpu_percent": Gauge(
        "cxr_hpa_ui_current_cpu_percent", "UI HPA current CPU %"
    ),
    "hpa_ui_target_cpu_percent": Gauge(
        "cxr_hpa_ui_target_cpu_percent", "UI HPA target CPU %"
    ),
    "analyzer_replicas": Gauge("cxr_analyzer_replicas", "Analyzer replica count"),
    "ui_replicas": Gauge("cxr_ui_replicas", "UI replica count"),
    "analyzer_pending_pods": Gauge("cxr_analyzer_pending_pods", "Analyzer pending pods"),
    "ui_pending_pods": Gauge("cxr_ui_pending_pods", "UI pending pods"),
    "analyzer_pod_cpu_mcores_sum": Gauge(
        "cxr_analyzer_pod_cpu_mcores_sum", "Sum analyzer pod CPU (millicores)"
    ),
    "ui_pod_cpu_mcores_sum": Gauge(
        "cxr_ui_pod_cpu_mcores_sum", "Sum UI pod CPU (millicores)"
    ),
    "node_cpu_percent": Gauge("cxr_node_cpu_percent", "Node CPU utilization %"),
    "node_memory_percent": Gauge("cxr_node_memory_percent", "Node memory utilization %"),
    "exporter_up": Gauge("cxr_load_exporter_up", "Last poll succeeded (1=yes)"),
}


def _num(value: object, default: float = 0.0) -> float:
    if value == "" or value is None:
        return default
    return float(value)


def apply_row(row: dict) -> None:
    G["locust_users"].set(row["locust_users"])
    G["locust_rps"].set(row["locust_rps"])
    G["locust_failures_per_second"].set(row["locust_failures_per_s"])
    G["locust_p50_ms"].set(row["locust_p50_ms"])
    G["locust_p95_ms"].set(row["locust_p95_ms"])
    G["hpa_analyzer_current_cpu_percent"].set(_num(row["hpa_analyzer_current_cpu_pct"]))
    G["hpa_analyzer_target_cpu_percent"].set(_num(row["hpa_analyzer_target_cpu_pct"]))
    G["hpa_ui_current_cpu_percent"].set(_num(row["hpa_ui_current_cpu_pct"]))
    G["hpa_ui_target_cpu_percent"].set(_num(row["hpa_ui_target_cpu_pct"]))
    G["analyzer_replicas"].set(_num(row["analyzer_replicas"]))
    G["ui_replicas"].set(_num(row["ui_replicas"]))
    G["analyzer_pending_pods"].set(row["analyzer_pending_pods"])
    G["ui_pending_pods"].set(row["ui_pending_pods"])
    G["analyzer_pod_cpu_mcores_sum"].set(row["analyzer_pod_cpu_mcores_sum"])
    G["ui_pod_cpu_mcores_sum"].set(row["ui_pod_cpu_mcores_sum"])
    G["node_cpu_percent"].set(row["node_cpu_pct"])
    G["node_memory_percent"].set(row["node_memory_pct"])
    G["exporter_up"].set(1)


def poll_loop(start_ts: float) -> None:
    while True:
        try:
            row = collect_row(start_ts, NAMESPACE, LOCUST_URL)
            apply_row(row)
        except Exception as exc:  # noqa: BLE001 — keep exporter alive
            G["exporter_up"].set(0)
            print(f"poll error: {exc}", file=sys.stderr)
        time.sleep(POLL_INTERVAL)


def main() -> None:
    print(
        f"cxr-load-exporter :{PORT}  namespace={NAMESPACE}  locust={LOCUST_URL}  "
        f"interval={POLL_INTERVAL}s",
        file=sys.stderr,
    )
    start_ts = time.time()
    start_http_server(PORT)
    poll_loop(start_ts)


if __name__ == "__main__":
    main()
