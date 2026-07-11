"""Shared Locust + Kubernetes polling (CSV collector + Prometheus exporter)."""

from __future__ import annotations

import json
import os
import subprocess
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from typing import Any

FIELDNAMES = [
    "timestamp_iso",
    "elapsed_s",
    "locust_users",
    "locust_rps",
    "locust_failures_per_s",
    "locust_p50_ms",
    "locust_p95_ms",
    "hpa_analyzer_target_cpu_pct",
    "hpa_analyzer_current_cpu_pct",
    "hpa_ui_target_cpu_pct",
    "hpa_ui_current_cpu_pct",
    "analyzer_replicas",
    "ui_replicas",
    "analyzer_pending_pods",
    "ui_pending_pods",
    "analyzer_pod_cpu_mcores_sum",
    "ui_pod_cpu_mcores_sum",
    "node_cpu_pct",
    "node_memory_pct",
]


def kubectl_json(args: list[str]) -> Any:
    cmd = ["kubectl"] + args + ["-o", "json"]
    try:
        out = subprocess.check_output(cmd, stderr=subprocess.DEVNULL, text=True)
        return json.loads(out)
    except (subprocess.CalledProcessError, FileNotFoundError, json.JSONDecodeError):
        return None


def parse_cpu_to_mcores(value: str) -> float:
    value = value.strip()
    if value.endswith("m"):
        return float(value[:-1])
    return float(value) * 1000.0


def parse_memory_to_bytes(value: str) -> float:
    value = value.strip()
    units = {"Ki": 1024, "Mi": 1024**2, "Gi": 1024**3, "Ti": 1024**4}
    for suffix, mult in units.items():
        if value.endswith(suffix):
            return float(value[: -len(suffix)]) * mult
    return float(value)


def deployment_ready_replicas(namespace: str, name: str) -> int:
    """Ready replicas from Deployment status (KEDA/Helm ground truth)."""
    data = kubectl_json(["get", "deployment", name, "-n", namespace])
    if not data:
        return 0
    status = data.get("status") or {}
    ready = status.get("readyReplicas")
    if ready is not None:
        return int(ready)
    return int(status.get("replicas") or 0)


def scaledobject_replicas(namespace: str, name: str) -> int | None:
    """KEDA ScaledObject status.currentReplicas when present."""
    data = kubectl_json(["get", "scaledobject", name, "-n", namespace])
    if not data:
        return None
    raw = (data.get("status") or {}).get("scaleTargetGVKR")
    _ = raw  # presence check only; replicas live on status
    current = (data.get("status") or {}).get("currentReplicas")
    if current is None:
        return None
    return int(current)


def analyzer_cpu_utilization_pct(
    namespace: str,
    *,
    pod_prefix: str = "cxr-analyzer-",
    cpu_request_mcores: float | None = None,
) -> int:
    """Synthetic CPU % when legacy HPA is absent (KEDA path)."""
    request_m = cpu_request_mcores
    if request_m is None:
        request_m = float(os.environ.get("CXR_ANALYZER_CPU_REQUEST_M", "500"))
    replicas = deployment_ready_replicas(namespace, "cxr-analyzer")
    if replicas <= 0:
        return 0
    total_m = pod_cpu_sum_mcores(namespace, pod_prefix)
    capacity = replicas * request_m
    if capacity <= 0:
        return 0
    return int(round(total_m / capacity * 100.0))


def hpa_metrics(namespace: str) -> dict[str, dict[str, float | int]]:
    data = kubectl_json(["get", "hpa", "-n", namespace])
    result: dict[str, dict[str, float | int]] = {}
    if not data:
        return result
    for item in data.get("items", []):
        name = item["metadata"]["name"]
        target = 0
        for m in item.get("spec", {}).get("metrics", []):
            if m.get("type") == "Resource" and m.get("resource", {}).get("name") == "cpu":
                target = m["resource"]["target"].get("averageUtilization") or 0
        current = 0
        for m in item.get("status", {}).get("currentMetrics") or []:
            if m.get("type") == "Resource" and m.get("resource", {}).get("name") == "cpu":
                current = m["resource"]["current"].get("averageUtilization") or 0
        result[name] = {
            "target_cpu_pct": int(target),
            "current_cpu_pct": int(current),
            "replicas": int(item.get("status", {}).get("currentReplicas") or 0),
        }
    return result


def pending_pods(namespace: str, prefix: str) -> int:
    data = kubectl_json(["get", "pods", "-n", namespace, "--field-selector=status.phase=Pending"])
    if not data:
        return 0
    count = 0
    for item in data.get("items", []):
        if item["metadata"]["name"].startswith(prefix):
            count += 1
    return count


def pod_cpu_sum_mcores(namespace: str, prefix: str) -> float:
    try:
        out = subprocess.check_output(
            ["kubectl", "top", "pods", "-n", namespace, "--no-headers"],
            stderr=subprocess.DEVNULL,
            text=True,
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        return 0.0
    total = 0.0
    for line in out.splitlines():
        parts = line.split()
        if len(parts) >= 2 and parts[0].startswith(prefix):
            total += parse_cpu_to_mcores(parts[1])
    return total


def node_utilization() -> tuple[float, float]:
    nodes = kubectl_json(["get", "nodes"])
    if not nodes or not nodes.get("items"):
        return 0.0, 0.0
    node_name = nodes["items"][0]["metadata"]["name"]
    alloc = nodes["items"][0]["status"].get("allocatable", {})
    alloc_cpu_m = parse_cpu_to_mcores(alloc.get("cpu", "0"))
    alloc_mem_b = parse_memory_to_bytes(alloc.get("memory", "0"))

    try:
        top = subprocess.check_output(
            ["kubectl", "top", "node", node_name, "--no-headers"],
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
        parts = top.split()
        if len(parts) >= 3:
            used_cpu_m = parse_cpu_to_mcores(parts[1])
            used_mem_b = parse_memory_to_bytes(parts[3] if len(parts) > 3 else parts[2])
            cpu_pct = (used_cpu_m / alloc_cpu_m * 100.0) if alloc_cpu_m else 0.0
            mem_pct = (used_mem_b / alloc_mem_b * 100.0) if alloc_mem_b else 0.0
            return round(cpu_pct, 1), round(mem_pct, 1)
    except (subprocess.CalledProcessError, FileNotFoundError, ValueError):
        pass
    return 0.0, 0.0


def fetch_locust_stats(base_url: str) -> dict[str, float]:
    url = base_url.rstrip("/") + "/stats/requests"
    try:
        with urllib.request.urlopen(url, timeout=3) as resp:
            payload = json.load(resp)
    except (urllib.error.URLError, json.JSONDecodeError, TimeoutError, OSError):
        return {}

    stats = payload.get("stats") or []
    row = next((s for s in stats if s.get("name") in ("Aggregated", "Total")), None)
    if not row and stats:
        row = stats[-1]

    users = float(payload.get("user_count") or payload.get("current_users") or 0)
    if not users and row:
        users = float(row.get("num_users") or 0)

    if not row:
        return {"users": users}

    p95 = float(row.get("response_time_percentile_0.95") or row.get("ninety_fifth_response_time") or 0)
    if not p95:
        for key, val in row.items():
            if key in ("95%", "95th") or "0.95" in str(key):
                p95 = float(val)
                break

    return {
        "users": users,
        "rps": float(row.get("current_rps") or 0),
        "failures_per_s": float(row.get("current_fail_per_sec") or 0),
        "p50_ms": float(row.get("median_response_time") or 0),
        "p95_ms": p95,
    }


def ramp_users(elapsed_s: float) -> int | None:
    start = os.environ.get("CXR_RAMP_START_USERS")
    step = os.environ.get("CXR_RAMP_STEP_USERS")
    stage = os.environ.get("CXR_RAMP_STAGE_SECONDS")
    max_u = os.environ.get("CXR_RAMP_MAX_USERS")
    if not all([start, step, stage]):
        return None
    stage_i = int(elapsed_s // float(stage))
    users = int(start) + stage_i * int(step)
    if max_u:
        users = min(users, int(max_u))
    return users


def collect_row(
    start_ts: float,
    namespace: str,
    locust_url: str,
) -> dict[str, Any]:
    elapsed = time.time() - start_ts
    locust = fetch_locust_stats(locust_url)
    users = locust.get("users") or 0
    estimated = ramp_users(elapsed)
    if (not users or users == 0) and estimated is not None:
        users = estimated

    hpa = hpa_metrics(namespace)
    an_hpa = hpa.get("cxr-analyzer", {})
    ui = hpa.get("cxr-ui", {})

    # OBS-002: KEDA removes legacy cxr-analyzer HPA — use Deployment readyReplicas.
    analyzer_reps = deployment_ready_replicas(namespace, "cxr-analyzer")
    keda_reps = scaledobject_replicas(namespace, "cxr-analyzer")
    if keda_reps is not None and keda_reps > analyzer_reps:
        analyzer_reps = keda_reps

    if an_hpa:
        an_cpu_current = an_hpa.get("current_cpu_pct", "")
        an_cpu_target = an_hpa.get("target_cpu_pct", "")
    else:
        an_cpu_current = analyzer_cpu_utilization_pct(namespace)
        an_cpu_target = int(os.environ.get("CXR_ANALYZER_CPU_TARGET_PCT", "70"))

    ui_reps = ui.get("replicas")
    if ui_reps in ("", None):
        ui_reps = deployment_ready_replicas(namespace, "cxr-ui")

    node_cpu, node_mem = node_utilization()

    return {
        "timestamp_iso": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "elapsed_s": round(elapsed, 1),
        "locust_users": int(users),
        "locust_rps": round(locust.get("rps", 0), 2),
        "locust_failures_per_s": round(locust.get("failures_per_s", 0), 3),
        "locust_p50_ms": round(locust.get("p50_ms", 0), 1),
        "locust_p95_ms": round(locust.get("p95_ms", 0), 1),
        "hpa_analyzer_target_cpu_pct": an_cpu_target,
        "hpa_analyzer_current_cpu_pct": an_cpu_current,
        "hpa_ui_target_cpu_pct": ui.get("target_cpu_pct", ""),
        "hpa_ui_current_cpu_pct": ui.get("current_cpu_pct", ""),
        "analyzer_replicas": analyzer_reps,
        "ui_replicas": ui_reps,
        "analyzer_pending_pods": pending_pods(namespace, "cxr-analyzer-"),
        "ui_pending_pods": pending_pods(namespace, "cxr-ui-"),
        "analyzer_pod_cpu_mcores_sum": round(pod_cpu_sum_mcores(namespace, "cxr-analyzer-"), 0),
        "ui_pod_cpu_mcores_sum": round(pod_cpu_sum_mcores(namespace, "cxr-ui-"), 0),
        "node_cpu_pct": node_cpu,
        "node_memory_pct": node_mem,
    }
