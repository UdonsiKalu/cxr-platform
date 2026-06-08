"""
CXR Claim Studio load — Locust web UI (SW load lab).

Host is set via --host on the CLI (see scripts/22-load-locust.sh).
Tasks: light GET /claim-studio + heavier POST /api/claim-studio/analyze.
"""

from __future__ import annotations

import json
import os

from locust import HttpUser, between, task

_ANALYZE_BODY = {
    "input": {
        "content": json.dumps(
            {
                "claim_id": os.environ.get("CXR_LOAD_CLAIM_ID", "locust-load"),
                "description": "office visit (load test)",
            }
        )
    }
}


class ClaimStudioUser(HttpUser):
    """Simulate analysts opening Claim Studio and running analysis."""

    wait_time = between(1, 4)

    @task(3)
    def claim_studio_page(self) -> None:
        with self.client.get("/claim-studio", name="GET /claim-studio", catch_response=True) as resp:
            if resp.status_code != 200:
                resp.failure(f"status {resp.status_code}")

    @task(1)
    def analyze_claim(self) -> None:
        with self.client.post(
            "/api/claim-studio/analyze",
            json=_ANALYZE_BODY,
            name="POST /api/claim-studio/analyze",
            timeout=120,
            catch_response=True,
        ) as resp:
            if resp.status_code != 200:
                resp.failure(f"status {resp.status_code}: {resp.text[:200]}")
