"""
Cumulative load ramp for GATE-001.

Profiles (CXR_RAMP_PROFILE):
  analyzer_saturation — 100% POST /api/claim-studio/analyze (OBS-001 comparable)
  lightweight_mixed   — 75% GET /claim-studio, 25% analyze (realistic app mix)

Env:
  CXR_RAMP_START_USERS, CXR_RAMP_STEP_USERS, CXR_RAMP_MAX_USERS
  CXR_RAMP_STAGE_SECONDS, CXR_RAMP_HOLD_AT_MAX_S
  CXR_CAPACITY_SPAWN_RATE
"""

from __future__ import annotations

import json
import os

from locust import HttpUser, LoadTestShape, between, task

_PROFILE = os.environ.get("CXR_RAMP_PROFILE", "lightweight_mixed")

_START = int(os.environ.get("CXR_RAMP_START_USERS", "25"))
_STEP = int(os.environ.get("CXR_RAMP_STEP_USERS", "25"))
_MAX = int(os.environ.get("CXR_RAMP_MAX_USERS", "200"))
_STAGE_SECONDS = int(os.environ.get("CXR_RAMP_STAGE_SECONDS", "90"))
_HOLD_AT_MAX_S = int(os.environ.get("CXR_RAMP_HOLD_AT_MAX_S", "120"))
_SPAWN_RATE = float(os.environ.get("CXR_CAPACITY_SPAWN_RATE", "5"))

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


class AnalyzeOnlyUser(HttpUser):
    """OBS-001 / analyzer-saturation — hammer analyze endpoint."""

    wait_time = between(1, 2)

    @task
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


class ClaimStudioMixedUser(HttpUser):
    """Lightweight — page views + occasional analyze."""

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


def _tier_count() -> int:
    if _START > _MAX:
        return 1
    return (_MAX - _START) // _STEP + 1


def ramp_duration_seconds() -> int:
    return _tier_count() * _STAGE_SECONDS + _HOLD_AT_MAX_S


class CumulativeRampShape(LoadTestShape):
    """Cumulative ramp in one session (no reset between tiers)."""

    def tick(self):
        run_time = self.get_run_time()
        ramp_end = _tier_count() * _STAGE_SECONDS
        if run_time >= ramp_end + _HOLD_AT_MAX_S:
            return None

        stage = min(int(run_time // _STAGE_SECONDS), _tier_count() - 1)
        users = min(_START + stage * _STEP, _MAX)
        return (users, _SPAWN_RATE)


# Locust runs every HttpUser subclass — expose exactly one per profile.
if _PROFILE == "analyzer_saturation":
    class ClaimStudioUser(AnalyzeOnlyUser):
        pass
else:
    class ClaimStudioUser(ClaimStudioMixedUser):
        pass
