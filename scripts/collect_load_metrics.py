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
import os
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib.load_metrics_poll import FIELDNAMES, collect_row


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
