#!/usr/bin/env python3
"""Continuous synthetic operational-readiness traffic → CXR analyze API + Prometheus metrics."""

from __future__ import annotations

import json
import os
import random
import string
import threading
import time
import uuid
from typing import Any

import httpx
from prometheus_client import Counter, Gauge, Histogram, start_http_server

PROFILE = os.environ.get("CXR_SYNTHETIC_PROFILE", "operational_readiness")
TARGET_URL = os.environ.get("CXR_SYNTHETIC_TARGET_URL", "http://127.0.0.1:8251").rstrip("/")
ANALYZE_PATH = os.environ.get("CXR_SYNTHETIC_ANALYZE_PATH", "/api/claim-studio/analyze")
ACTIVE_USERS = max(1, int(os.environ.get("CXR_SYNTHETIC_ACTIVE_USERS", "3")))
MIN_INTERVAL_S = float(os.environ.get("CXR_SYNTHETIC_MIN_INTERVAL_S", "8"))
MAX_INTERVAL_S = float(os.environ.get("CXR_SYNTHETIC_MAX_INTERVAL_S", "20"))
METRICS_PORT = int(os.environ.get("CXR_SYNTHETIC_METRICS_PORT", "9103"))
REQUEST_TIMEOUT_S = float(os.environ.get("CXR_SYNTHETIC_TIMEOUT_S", "120"))

REQUESTS = Counter(
    "synthetic_requests_total",
    "Synthetic readiness requests",
    ["profile", "method", "status"],
)
FAILURES = Counter(
    "synthetic_failures_total",
    "Synthetic readiness failures",
    ["profile", "reason"],
)
ACTIVE = Gauge("synthetic_active_users", "Concurrent synthetic workers", ["profile"])
PROFILE_INFO = Gauge(
    "synthetic_profile",
    "Synthetic traffic profile marker (1 = active)",
    ["profile"],
)
LATENCY = Histogram(
    "synthetic_request_latency_seconds",
    "Synthetic request latency",
    ["profile", "method"],
    buckets=(0.5, 1, 2, 3, 5, 8, 12, 20, 30, 60, 120),
)

DESCRIPTIONS = [
    "office visit (synthetic readiness)",
    "lab panel review (synthetic)",
    "follow-up claim check (readiness)",
    "prior auth synthetic probe",
    "claim routing readiness test",
]

_stop = threading.Event()
_active_count = 0
_active_lock = threading.Lock()


def _rand_claim_id() -> str:
    suffix = "".join(random.choices(string.ascii_lowercase + string.digits, k=8))
    return f"synth-{uuid.uuid4().hex[:8]}-{suffix}"


def _analyze_body() -> dict[str, Any]:
    return {
        "input": {
            "content": json.dumps(
                {
                    "claim_id": _rand_claim_id(),
                    "description": random.choice(DESCRIPTIONS),
                }
            )
        }
    }


def _inc_active(delta: int) -> None:
    global _active_count
    with _active_lock:
        _active_count += delta
        ACTIVE.labels(profile=PROFILE).set(_active_count)


def _worker(worker_id: int) -> None:
    _inc_active(1)
    url = f"{TARGET_URL}{ANALYZE_PATH}"
    try:
        with httpx.Client(timeout=REQUEST_TIMEOUT_S) as client:
            while not _stop.is_set():
                method = "POST"
                t0 = time.perf_counter()
                status = "error"
                try:
                    resp = client.post(url, json=_analyze_body())
                    elapsed = time.perf_counter() - t0
                    LATENCY.labels(profile=PROFILE, method=method).observe(elapsed)
                    if resp.status_code == 200:
                        status = "200"
                        REQUESTS.labels(profile=PROFILE, method=method, status=status).inc()
                    else:
                        status = str(resp.status_code)
                        REQUESTS.labels(profile=PROFILE, method=method, status=status).inc()
                        FAILURES.labels(profile=PROFILE, reason=f"http_{resp.status_code}").inc()
                except httpx.TimeoutException:
                    elapsed = time.perf_counter() - t0
                    LATENCY.labels(profile=PROFILE, method=method).observe(elapsed)
                    REQUESTS.labels(profile=PROFILE, method=method, status="timeout").inc()
                    FAILURES.labels(profile=PROFILE, reason="timeout").inc()
                except Exception:
                    elapsed = time.perf_counter() - t0
                    LATENCY.labels(profile=PROFILE, method=method).observe(elapsed)
                    REQUESTS.labels(profile=PROFILE, method=method, status="error").inc()
                    FAILURES.labels(profile=PROFILE, reason="exception").inc()

                wait = random.uniform(MIN_INTERVAL_S, MAX_INTERVAL_S)
                if _stop.wait(wait):
                    break
    finally:
        _inc_active(-1)


def main() -> None:
    PROFILE_INFO.labels(profile=PROFILE).set(1)
    start_http_server(METRICS_PORT)
    print(
        f"synthetic-readiness: profile={PROFILE} target={TARGET_URL}{ANALYZE_PATH} "
        f"users={ACTIVE_USERS} metrics=: {METRICS_PORT}",
        flush=True,
    )

    threads = [
        threading.Thread(target=_worker, args=(i,), name=f"synth-{i}", daemon=True)
        for i in range(ACTIVE_USERS)
    ]
    for t in threads:
        t.start()

    try:
        while True:
            time.sleep(5)
    except KeyboardInterrupt:
        print("shutting down synthetic-readiness...", flush=True)
        _stop.set()
        for t in threads:
            t.join(timeout=2)


if __name__ == "__main__":
    main()
