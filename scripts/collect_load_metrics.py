#!/usr/bin/env python3
"""
Poll Locust + Kubernetes metrics during a load test → single CSV time series.

Usage (background while Locust runs):
  export PATH="$PWD/bin:$PATH"
  python3 scripts/collect_load_metrics.py --output /tmp/load-run.csv

See cxr-portfolio/investigations/kubernetes-analyzer-saturation/README.md
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import re
import subprocess
import sys
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
    except (urllib.error.URLError, json.JSONDecodeError, TimeoutError):
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
    """Estimate users from ContinuousRampShape env (LOAD-002/003 saturation scripts)."""
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
    an = hpa.get("cxr-analyzer", {})
    ui = hpa.get("cxr-ui", {})
    node_cpu, node_mem = node_utilization()

    return {
        "timestamp_iso": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "elapsed_s": round(elapsed, 1),
        "locust_users": int(users),
        "locust_rps": round(locust.get("rps", 0), 2),
        "locust_failures_per_s": round(locust.get("failures_per_s", 0), 3),
        "locust_p50_ms": round(locust.get("p50_ms", 0), 1),
        "locust_p95_ms": round(locust.get("p95_ms", 0), 1),
        "hpa_analyzer_target_cpu_pct": an.get("target_cpu_pct", ""),
        "hpa_analyzer_current_cpu_pct": an.get("current_cpu_pct", ""),
        "hpa_ui_target_cpu_pct": ui.get("target_cpu_pct", ""),
        "hpa_ui_current_cpu_pct": ui.get("current_cpu_pct", ""),
        "analyzer_replicas": an.get("replicas", ""),
        "ui_replicas": ui.get("replicas", ""),
        "analyzer_pending_pods": pending_pods(namespace, "cxr-analyzer-"),
        "ui_pending_pods": pending_pods(namespace, "cxr-ui-"),
        "analyzer_pod_cpu_mcores_sum": round(pod_cpu_sum_mcores(namespace, "cxr-analyzer-"), 0),
        "ui_pod_cpu_mcores_sum": round(pod_cpu_sum_mcores(namespace, "cxr-ui-"), 0),
        "node_cpu_pct": node_cpu,
        "node_memory_pct": node_mem,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Collect Locust + K8 metrics to CSV")
    parser.add_argument("--output", "-o", required=True, help="Output CSV path")
    parser.add_argument("--interval", "-i", type=float, default=5.0, help="Poll interval seconds")
    parser.add_argument("--duration", "-d", type=float, default=0, help="Stop after N seconds (0=until Ctrl+C)")
    parser.add_argument("--namespace", "-n", default=os.environ.get("CXR_K8_NAMESPACE", "cxr-ui"))
    parser.add_argument(
        "--locust-url",
        default=os.environ.get("CXR_LOCUST_URL", "http://127.0.0.1:8090"),
        help="Locust web UI base URL",
    )
    args = parser.parse_args()

    os.makedirs(os.path.dirname(os.path.abspath(args.output)) or ".", exist_ok=True)
    start = time.time()
    write_header = not os.path.exists(args.output) or os.path.getsize(args.output) == 0

    print(f"Collecting every {args.interval}s → {args.output}", file=sys.stderr)
    print(f"  namespace={args.namespace}  locust={args.locust_url}", file=sys.stderr)
    print("  Ctrl+C to stop", file=sys.stderr)

    try:
        with open(args.output, "a", newline="", encoding="utf-8") as fh:
            writer = csv.DictWriter(fh, fieldnames=FIELDNAMES)
            if write_header:
                writer.writeheader()
            while True:
                row = collect_row(start, args.namespace, args.locust_url)
                writer.writerow(row)
                fh.flush()
                print(
                    f"  t={row['elapsed_s']:6.0f}s  users={row['locust_users']:4}  "
                    f"rps={row['locust_rps']:5.1f}  "
                    f"an={row['analyzer_replicas']}/{row['hpa_analyzer_current_cpu_pct']}%  "
                    f"ui={row['ui_replicas']}/{row['hpa_ui_current_cpu_pct']}%  "
                    f"pending={row['analyzer_pending_pods']}",
                    file=sys.stderr,
                )
                if args.duration and (time.time() - start) >= args.duration:
                    break
                time.sleep(args.interval)
    except KeyboardInterrupt:
        print("\nStopped.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
