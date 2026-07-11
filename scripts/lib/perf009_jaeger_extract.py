#!/usr/bin/env python3
"""PERF-009 — extract fast vs slow Jaeger POST traces and span breakdown tables."""
from __future__ import annotations

import argparse
import json
import statistics
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

JAEGER_DEFAULT = "http://127.0.0.1:16686"
UI_SERVICE = "cxr-ui-k8"
UI_OPERATION = "POST"

# Canonical stages for comparison table (ms).
STAGE_KEYS = [
    ("ui_total", "UI POST (root)"),
    ("ui_route", "UI route handler"),
    ("analyzer_http", "UI → analyzer HTTP (fetch)"),
    ("http_wait", "HTTP/client wait (fetch − analyze_request)"),
    ("analyze_request", "analyzer_service.analyze_request"),
    ("claim_analysis", "claim_analysis"),
    ("archetype_reasoning", "archetype_reasoning"),
    ("context_builder", "context_builder"),
    ("policy_extraction", "policy extraction (context.7_policy*)"),
    ("retrieval", "retrieval"),
    ("llm_inference", "LLM / Ollama (llm_inference*)"),
    ("save_result", "save_result"),
]


@dataclass
class SpanRow:
    trace_id: str
    total_ms: float
    spans: dict[str, float] = field(default_factory=dict)

    def jaeger_url(self, base: str) -> str:
        return f"{base.rstrip('/')}/trace/{self.trace_id}"


def _fetch_traces(
    base: str,
    *,
    start_us: int | None,
    end_us: int | None,
    min_dur: str | None,
    max_dur: str | None,
    limit: int,
) -> list[dict[str, Any]]:
    params: dict[str, str] = {
        "service": UI_SERVICE,
        "operation": UI_OPERATION,
        "limit": str(limit),
    }
    if start_us is not None:
        params["start"] = str(start_us)
    if end_us is not None:
        params["end"] = str(end_us)
    if min_dur:
        params["minDuration"] = min_dur
    if max_dur:
        params["maxDuration"] = max_dur
    url = f"{base.rstrip('/')}/api/traces?{urllib.parse.urlencode(params)}"
    with urllib.request.urlopen(url, timeout=60) as resp:
        payload = json.load(resp)
    return payload.get("data") or []


def _span_duration_ms(span: dict[str, Any]) -> float:
    return span.get("duration", 0) / 1000.0


def _roots(spans: list[dict[str, Any]]) -> list[dict[str, Any]]:
    children: set[str] = set()
    for span in spans:
        for ref in span.get("references") or []:
            if ref.get("refType") == "CHILD_OF":
                children.add(ref["spanID"])
    roots = [s for s in spans if s["spanID"] not in children]
    return roots or spans


def _pick_root(spans: list[dict[str, Any]]) -> dict[str, Any]:
    roots = _roots(spans)
    ui_roots = [r for r in roots if r.get("operationName") == UI_OPERATION]
    pool = ui_roots or roots
    return max(pool, key=lambda s: s.get("startTime", 0))


def _ui_total_ms(spans: list[dict[str, Any]]) -> float:
    """E2E UI latency — longest POST or analyze API span (Jaeger root duration is unreliable)."""
    candidates = []
    for span in spans:
        op = span.get("operationName") or ""
        if op == UI_OPERATION or op.startswith("POST /api/claim-studio"):
            candidates.append(_span_duration_ms(span))
    if candidates:
        return max(candidates)
    root = _pick_root(spans)
    return _span_duration_ms(root)


def _max_duration_by_prefix(spans: list[dict[str, Any]], prefix: str) -> float:
    hits = [_span_duration_ms(s) for s in spans if (s.get("operationName") or "").startswith(prefix)]
    return max(hits) if hits else 0.0


def _max_duration_exact(spans: list[dict[str, Any]], name: str) -> float:
    hits = [_span_duration_ms(s) for s in spans if s.get("operationName") == name]
    return max(hits) if hits else 0.0


def _policy_extraction_ms(spans: list[dict[str, Any]]) -> float:
  total = 0.0
  for span in spans:
    op = span.get("operationName") or ""
    if op.startswith("context.7_policy") or op.startswith("llm.prompt_construction"):
      total = max(total, _span_duration_ms(span))
    if op == "context.7_policy":
      total = max(total, _span_duration_ms(span))
  return total


def _llm_ms(spans: list[dict[str, Any]]) -> float:
    prefixes = ("llm_inference", "llm.model_request", "llm.model_response", "llm.prompt_construction")
    hits = [_span_duration_ms(s) for s in spans if any((s.get("operationName") or "").startswith(p) for p in prefixes)]
    return max(hits) if hits else 0.0


def parse_trace(trace: dict[str, Any]) -> SpanRow | None:
    spans = trace.get("spans") or []
    if not spans:
        return None
    total_ms = _ui_total_ms(spans)
    analyze_ms = _max_duration_exact(spans, "analyzer_service.analyze_request")
    fetch_ms = _max_duration_by_prefix(spans, "fetch POST http://cxr-analyzer")
    if fetch_ms <= 0:
        fetch_ms = _max_duration_by_prefix(spans, "fetch POST")

    http_wait = max(0.0, fetch_ms - analyze_ms) if fetch_ms and analyze_ms else 0.0

    row = SpanRow(
        trace_id=trace.get("traceID", ""),
        total_ms=total_ms,
        spans={
            "ui_total": total_ms,
            "ui_route": _max_duration_by_prefix(spans, "executing api route"),
            "analyzer_http": fetch_ms,
            "http_wait": http_wait,
            "analyze_request": analyze_ms,
            "claim_analysis": _max_duration_exact(spans, "claim_analysis"),
            "archetype_reasoning": _max_duration_exact(spans, "archetype_reasoning"),
            "context_builder": _max_duration_exact(spans, "context_builder"),
            "policy_extraction": _policy_extraction_ms(spans),
            "retrieval": _max_duration_exact(spans, "retrieval"),
            "llm_inference": _llm_ms(spans),
            "save_result": _max_duration_exact(spans, "save_result"),
        },
    )
    return row


def _median_near(traces: list[SpanRow], target_ms: float, n: int) -> list[SpanRow]:
    if not traces:
        return []
    ranked = sorted(traces, key=lambda t: abs(t.total_ms - target_ms))
    return ranked[:n]


def collect_rows(
    base: str,
    *,
    start_us: int | None,
    end_us: int | None,
    fast_min: str,
    fast_max: str,
    slow_min: str,
    slow_max: str,
    limit: int,
    per_bucket: int,
) -> dict[str, Any]:
    fast_raw = _fetch_traces(
        base,
        start_us=start_us,
        end_us=end_us,
        min_dur=fast_min,
        max_dur=fast_max,
        limit=limit,
    )
    slow_raw = _fetch_traces(
        base,
        start_us=start_us,
        end_us=end_us,
        min_dur=slow_min,
        max_dur=slow_max,
        limit=limit,
    )

    fast_parsed = [r for t in fast_raw if (r := parse_trace(t))]
    slow_parsed = [r for t in slow_raw if (r := parse_trace(t))]

    fast_pick = _median_near(fast_parsed, target_ms=150, n=per_bucket)
    slow_pick = _median_near(slow_parsed, target_ms=800, n=per_bucket)

    def bucket_stats(rows: list[SpanRow]) -> dict[str, float]:
        if not rows:
            return {}
        out: dict[str, float] = {}
        for key, _label in STAGE_KEYS:
            vals = [r.spans.get(key, 0.0) for r in rows]
            out[key] = round(statistics.median(vals), 1)
        out["ui_total"] = round(statistics.median([r.total_ms for r in rows]), 1)
        return out

    return {
        "fast_candidates": len(fast_parsed),
        "slow_candidates": len(slow_parsed),
        "fast_traces": [
            {"trace_id": r.trace_id, "total_ms": round(r.total_ms, 1), "spans": r.spans, "url": r.jaeger_url(base)}
            for r in fast_pick
        ],
        "slow_traces": [
            {"trace_id": r.trace_id, "total_ms": round(r.total_ms, 1), "spans": r.spans, "url": r.jaeger_url(base)}
            for r in slow_pick
        ],
        "fast_median_spans_ms": bucket_stats(fast_pick),
        "slow_median_spans_ms": bucket_stats(slow_pick),
    }


def markdown_table(fast: dict[str, float], slow: dict[str, float]) -> str:
    lines = ["| Span | Fast (median ms) | Slow (median ms) | Δ slow − fast |", "|------|------------------|------------------|---------------|"]
    for key, label in STAGE_KEYS:
        f = fast.get(key, 0.0)
        s = slow.get(key, 0.0)
        delta = round(s - f, 1)
        lines.append(f"| {label} | {f} | {s} | {delta:+} |")
    return "\n".join(lines)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--jaeger", default=JAEGER_DEFAULT)
    ap.add_argument("--start-us", type=int, default=None)
    ap.add_argument("--end-us", type=int, default=None)
    ap.add_argument("--fast-min", default="80ms")
    ap.add_argument("--fast-max", default="250ms")
    ap.add_argument("--slow-min", default="600ms")
    ap.add_argument("--slow-max", default="1200ms")
    ap.add_argument("--limit", type=int, default=80)
    ap.add_argument("--per-bucket", type=int, default=3)
    ap.add_argument("--experiment", required=True, choices=["A", "B"])
    ap.add_argument("--stamp", required=True)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()

    result = collect_rows(
        args.jaeger,
        start_us=args.start_us,
        end_us=args.end_us,
        fast_min=args.fast_min,
        fast_max=args.fast_max,
        slow_min=args.slow_min,
        slow_max=args.slow_max,
        limit=args.limit,
        per_bucket=args.per_bucket,
    )
    result["experiment"] = args.experiment
    result["stamp"] = args.stamp
    if args.start_us:
        result["start_us"] = args.start_us
    if args.end_us:
        result["end_us"] = args.end_us

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")

    fast = result.get("fast_median_spans_ms") or {}
    slow = result.get("slow_median_spans_ms") or {}
    md_path = args.out.with_suffix(".md")
    md_path.write_text(
        f"# PERF-009 extract — Experiment {args.experiment} @ {args.stamp}\n\n"
        f"Fast candidates: {result['fast_candidates']} | Slow candidates: {result['slow_candidates']}\n\n"
        + markdown_table(fast, slow)
        + "\n",
        encoding="utf-8",
    )
    print(f"Wrote {args.out} ({result['fast_candidates']} fast / {result['slow_candidates']} slow candidates)")


if __name__ == "__main__":
    main()
