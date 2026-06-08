import http from "k6/http";
import { check, sleep } from "k6";

const BASE = __ENV.CXR_LOAD_URL || "http://127.0.0.1:3000";
const VUS = Number(__ENV.K6_VUS || 3);
const DURATION = __ENV.K6_DURATION || "2m";

export const options = {
  vus: VUS,
  duration: DURATION,
  thresholds: {
    http_req_failed: ["rate<0.15"],
    http_req_duration: ["p(95)<120000"],
  },
};

const analyzePayload = JSON.stringify({
  input: {
    content: JSON.stringify({
      claim_id: __ENV.CXR_LOAD_CLAIM_ID || "k6-load",
      description: "office visit (load test)",
    }),
  },
});

export default function () {
  const page = http.get(`${BASE}/claim-studio`, { tags: { name: "GET /claim-studio" } });
  check(page, { "claim-studio 200": (r) => r.status === 200 });

  const res = http.post(`${BASE}/api/claim-studio/analyze`, analyzePayload, {
    headers: { "Content-Type": "application/json" },
    timeout: "120s",
    tags: { name: "POST /api/claim-studio/analyze" },
  });
  check(res, { "analyze 200": (r) => r.status === 200 });

  sleep(1);
}

export function handleSummary(data) {
  const p95 = data.metrics.http_req_duration?.values?.["p(95)"];
  const failed = data.metrics.http_req_failed?.values?.rate;
  return {
    stdout: [
      "",
      "=== CXR k6 load summary ===",
      `Target: ${BASE}`,
      `VUs: ${VUS}  Duration: ${DURATION}`,
      p95 != null ? `p95 latency: ${(p95 / 1000).toFixed(2)}s` : "",
      failed != null ? `failed rate: ${(failed * 100).toFixed(1)}%` : "",
      "During run: Jaeger http://localhost:16686  Grafana http://localhost:3001",
      "",
    ].join("\n"),
  };
}
