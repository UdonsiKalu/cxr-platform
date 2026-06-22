#!/usr/bin/env python3
"""GATE-002 — grid search over tuner_config.yaml; score gate JSON reports."""

from __future__ import annotations

import argparse
import itertools
import json
import math
from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError:
    yaml = None  # type: ignore


def load_config(path: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8")
    if yaml is None:
        raise SystemExit("PyYAML required: pip install pyyaml")
    return yaml.safe_load(text)


def expand_search(cfg: dict[str, Any]) -> list[dict[str, Any]]:
    search = cfg.get("search") or {}
    flat: dict[str, list[Any]] = {}
    for component, keys in search.items():
        prefix = "analyzer" if component == "analyzer" else "ui"
        for key, values in (keys or {}).items():
            flat[f"{prefix}.{key}"] = list(values)
    if not flat:
        return [{}]
    names = list(flat.keys())
    combos = []
    for vals in itertools.product(*(flat[n] for n in names)):
        combos.append(dict(zip(names, vals)))
    return combos


def stage_score(stage: dict[str, Any], slos: dict[str, Any], weights: dict[str, Any]) -> float:
    w_col = float(weights.get("collapse_weight", 1000))
    w_fail = float(weights.get("failure_weight", 100))
    w_p95 = float(weights.get("p95_weight", 1))
    w_rps = float(weights.get("rps_bonus", 10))

    users = int(stage.get("users_target", 0))
    max_p95_limits = slos.get("max_p95_ms") or {}
    p95_limit = float(max_p95_limits.get(users, max_p95_limits.get(str(users), 5000)))

    collapses = int(stage.get("collapse_count", 0))
    max_fail = float(stage.get("max_failures_per_s", 0))
    max_p95 = float(stage.get("max_p95_ms", 0))
    max_rps = float(stage.get("max_rps", 0))

    max_collapses = int(slos.get("max_collapses", 0))
    max_fail_slo = float(slos.get("max_failures_per_s", 0.5))

    score = 0.0
    score += w_col * max(0, collapses - max_collapses)
    score += w_fail * max(0, max_fail - max_fail_slo)
    score += w_p95 * max(0, max_p95 - p95_limit)
    score -= w_rps * max_rps
    if not stage.get("pass", False):
        score += 5000
    return score


def score_gate_report(report_path: Path, cfg: dict[str, Any]) -> dict[str, Any]:
    data = json.loads(report_path.read_text(encoding="utf-8"))
    slos = cfg.get("slos") or {}
    weights = cfg.get("score") or {}
    stages = data.get("stages") or []
    total = sum(stage_score(s, slos, weights) for s in stages)
    all_pass = all(s.get("pass") for s in stages) and bool(stages)
    return {
        "score": total,
        "all_pass": all_pass,
        "stages": stages,
        "gate_report": str(report_path),
    }


def helm_set_args(candidate: dict[str, Any]) -> list[str]:
    args: list[str] = []
    mapping = {
        "analyzer.autoscaling.maxReplicas": "autoscaling.maxReplicas",
        "analyzer.autoscaling.minReplicas": "autoscaling.minReplicas",
        "analyzer.autoscaling.keda.prometheus.p95ThresholdMs": "autoscaling.keda.prometheus.p95ThresholdMs",
        "ui.autoscaling.maxReplicas": None,
    }
    for k, v in candidate.items():
        if k.startswith("ui."):
            chart_key = k.replace("ui.", "", 1)
            args.extend(["--set", f"ui.{chart_key}={v}"])
        elif k.startswith("analyzer."):
            chart_key = k.replace("analyzer.", "", 1)
            args.extend(["--set", f"{chart_key}={v}"])
    return args


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("config", type=Path)
    parser.add_argument("--list-candidates", action="store_true")
    parser.add_argument("--score-report", type=Path)
    parser.add_argument("--candidate-json", type=Path)
    args = parser.parse_args()

    cfg = load_config(args.config)
    if args.list_candidates:
        for i, c in enumerate(expand_search(cfg)):
            print(json.dumps({"id": i, "candidate": c}))
        return 0

    if args.score_report:
        result = score_gate_report(args.score_report, cfg)
        print(json.dumps(result, indent=2))
        return 0

    if args.candidate_json:
        print(json.dumps(expand_search(cfg)[int(args.candidate_json.read_text())]))
        return 0

    parser.print_help()
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
