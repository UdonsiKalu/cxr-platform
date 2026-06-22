#!/usr/bin/env python3
"""Score a LOAD gate CSV stage — collapses, failures/s, p95."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path


def _f(row: dict, key: str, default: float = 0.0) -> float:
    raw = row.get(key, "")
    if raw == "" or raw is None:
        return default
    return float(raw)


def _i(row: dict, key: str, default: int = 0) -> int:
    return int(_f(row, key, float(default)))


def rows_for_tier(
    rows: list[dict],
    users_target: int,
    *,
    ramp_step: int = 0,
    is_max_tier: bool = False,
) -> list[dict]:
    """Discrete stage: rows at/above target. Cumulative ramp: plateau window at target."""
    if ramp_step <= 0:
        min_users = max(10, int(users_target * 0.5))
        return [r for r in rows if _f(r, "locust_users") >= min_users]

    band = ramp_step * 0.45
    if is_max_tier:
        return [r for r in rows if _f(r, "locust_users") >= users_target - band]
    low = users_target - band
    high = users_target + band
    return [r for r in rows if low <= _f(r, "locust_users") <= high]


def score_csv(
    path: Path,
    *,
    users_target: int,
    max_p95_ms: float,
    max_failures_per_s: float,
    max_collapses: int,
    collapse_high: int = 5,
    collapse_low: int = 2,
    min_users: int = 10,
    ramp_step: int = 0,
    is_max_tier: bool = False,
) -> dict:
    rows = list(csv.DictReader(path.open(encoding="utf-8")))
    active = rows_for_tier(
        rows,
        users_target,
        ramp_step=ramp_step,
        is_max_tier=is_max_tier,
    )
    if not active:
        active = [r for r in rows if _f(r, "locust_users") >= min_users]
    if not active:
        active = rows

    collapses: list[dict] = []
    prev_rep: int | None = None
    for r in active:
        rep = _i(r, "analyzer_replicas")
        if prev_rep is not None and prev_rep >= collapse_high and rep <= collapse_low:
            collapses.append(
                {
                    "timestamp": r.get("timestamp_iso", ""),
                    "from": prev_rep,
                    "to": rep,
                    "failures_per_s": _f(r, "locust_failures_per_s"),
                    "users": _f(r, "locust_users"),
                }
            )
        prev_rep = rep

    max_p95 = max((_f(r, "locust_p95_ms") for r in active), default=0.0)
    max_fail = max((_f(r, "locust_failures_per_s") for r in active), default=0.0)
    max_rps = max((_f(r, "locust_rps") for r in active), default=0.0)
    max_users = max((_f(r, "locust_users") for r in active), default=0.0)
    max_pending = max((_i(r, "analyzer_pending_pods") for r in active), default=0)
    max_rep = max((_i(r, "analyzer_replicas") for r in active), default=0)

    reasons: list[str] = []
    if len(collapses) > max_collapses:
        reasons.append(f"collapses {len(collapses)} > {max_collapses}")
    if max_fail > max_failures_per_s:
        reasons.append(f"failures/s peak {max_fail:.2f} > {max_failures_per_s}")
    if max_p95 > max_p95_ms:
        reasons.append(f"p95 peak {max_p95:.0f}ms > {max_p95_ms:.0f}ms")
    if max_users < users_target * 0.85:
        reasons.append(f"users peak {max_users:.0f} < target {users_target}")

    return {
        "csv": str(path),
        "users_target": users_target,
        "samples": len(active),
        "max_users": max_users,
        "max_rps": max_rps,
        "max_p95_ms": max_p95,
        "max_failures_per_s": max_fail,
        "max_analyzer_replicas": max_rep,
        "max_pending_pods": max_pending,
        "collapse_count": len(collapses),
        "collapses": collapses[:10],
        "pass": len(reasons) == 0,
        "reasons": reasons,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Score LOAD gate CSV stage")
    parser.add_argument("csv", type=Path)
    parser.add_argument("--users", type=int, required=True)
    parser.add_argument("--max-p95-ms", type=float, default=0)
    parser.add_argument("--max-failures-per-s", type=float, default=0.5)
    parser.add_argument("--max-collapses", type=int, default=0)
    parser.add_argument("--ramp-step", type=int, default=0, help="Cumulative ramp step (e.g. 25)")
    parser.add_argument("--max-tier", action="store_true", help="Score plateau at ramp max users")
    parser.add_argument("--soft", action="store_true", help="Report only; always exit 0")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    if args.max_p95_ms <= 0:
        defaults = {
            25: 2000,
            50: 2500,
            75: 3000,
            100: 3500,
            125: 4000,
            150: 5000,
            175: 5500,
            200: 6500,
        }
        args.max_p95_ms = float(defaults.get(args.users, 5000))

    result = score_csv(
        args.csv,
        users_target=args.users,
        max_p95_ms=args.max_p95_ms,
        max_failures_per_s=args.max_failures_per_s,
        max_collapses=args.max_collapses,
        ramp_step=args.ramp_step,
        is_max_tier=args.max_tier,
    )

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        status = "PASS" if result["pass"] else "FAIL"
        print(f"[{status}] stage users={args.users}")
        print(
            f"  rps={result['max_rps']:.1f} p95={result['max_p95_ms']:.0f}ms "
            f"fail/s={result['max_failures_per_s']:.2f} "
            f"collapses={result['collapse_count']} replicas_max={result['max_analyzer_replicas']}"
        )
        for reason in result["reasons"]:
            print(f"  - {reason}")

    if args.soft:
        return 0
    return 0 if result["pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
