#!/usr/bin/env python3
"""Summarize a PERF-008 experiment run into comparison-table rows (CSV + optional Prometheus)."""

from __future__ import annotations

import argparse
import csv
import json
import sys
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts"))
from lib.load_gate_score import score_csv  # noqa: E402


def _rows(path: Path) -> list[dict]:
    with path.open(newline="") as fh:
        return list(csv.DictReader(fh))


def _f(row: dict, key: str, default: float = 0.0) -> float:
    raw = row.get(key, "")
    if raw in ("", None):
        return default
    return float(raw)


def _prom_query(expr: str, prom: str) -> float | None:
    url = f"{prom.rstrip('/')}/api/v1/query?" + urllib.parse.urlencode({"query": expr})
    try:
        with urllib.request.urlopen(url, timeout=5) as resp:
            payload = json.load(resp)
    except OSError:
        return None
    result = payload.get("data", {}).get("result") or []
    if not result:
        return None
    return float(result[0]["value"][1])


def summarize_csv(csv_path: Path, *, users_target: int = 200) -> dict:
    rows = _rows(csv_path)
    active = [r for r in rows if _f(r, "locust_users") >= 50]
    if not active:
        active = rows

    p95_vals = [_f(r, "locust_p95_ms") for r in active if _f(r, "locust_p95_ms") > 0]
    max_p95 = max(p95_vals) if p95_vals else 0.0
    p95_slope = 0.0
    if len(p95_vals) >= 2:
        p95_slope = (p95_vals[-1] - p95_vals[0]) / max(len(p95_vals) - 1, 1)

    max_fail = max((_f(r, "locust_failures_per_s") for r in active), default=0.0)
    max_rep = max((_f(r, "analyzer_replicas") for r in active), default=0.0)

    scored = score_csv(
        csv_path,
        users_target=users_target,
        max_p95_ms=99999,
        max_failures_per_s=999,
        max_collapses=999,
        ramp_step=15,
        is_max_tier=True,
    )

    return {
        "csv": str(csv_path),
        "max_p95_ms": round(max_p95, 1),
        "p95_slope_ms_per_sample": round(p95_slope, 2),
        "max_failures_per_s": round(max_fail, 3),
        "max_analyzer_replicas_csv": int(max_rep),
        "replica_oscillation_collapses": scored.get("collapse_count", 0),
        "gate_all_pass": scored.get("all_pass"),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="PERF-008 run summary")
    parser.add_argument("--experiment", choices=["a", "b"], required=True)
    parser.add_argument("--dir", type=Path, required=True, help="Run output directory")
    parser.add_argument("--prometheus", default="http://127.0.0.1:9090")
    args = parser.parse_args()

    csvs = sorted(args.dir.glob("*.csv")) + sorted(args.dir.glob("**/*.csv"))
    if not csvs:
        print(f"No CSV in {args.dir}", file=sys.stderr)
        sys.exit(1)
    csv_path = csvs[-1]

    summary = summarize_csv(csv_path)
    summary["experiment"] = args.experiment.upper()
    summary["max_inflight"] = _prom_query("max_over_time(sum(cxr_analyzer_inflight_requests)[1h])", args.prometheus)
    summary["queue_wait_p95_s"] = _prom_query("max_over_time(cxr_analyzer_queue_wait_p95[1h])", args.prometheus)
    summary["replica_changes_5m_max"] = _prom_query(
        "max_over_time(cxr_analyzer_replica_changes_5m[1h])", args.prometheus
    )
    summary["time_backpressure_to_scale_s"] = None  # fill from Grafana annotations / manual review

    print(json.dumps(summary, indent=2))
    print("\nPaste into docs/PERF-008-queue-depth-autoscaling.md comparison table.", file=sys.stderr)


if __name__ == "__main__":
    main()
