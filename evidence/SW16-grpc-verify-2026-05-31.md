# SW.16 gRPC verify — 2026-05-31

- Timestamp: 2026-05-31T08:22-05:00
- Stack: `./scripts/19-grpc-up.sh`
- Smoke: `./scripts/19-grpc-smoke.sh`

## Checklist

- [x] `compose.grpc.yaml` up — `grpc-analysis` + `grpc-ui`
- [x] **:50051** — `GetClaimStatus` / `AnalyzeClaim` return `demo-1` / `ok` (agent smoke 2026-05-31)
- [x] **:8090** grpcui loads — **AnalyzeClaim** form for `cxr.v1.ClaimAnalysis` (user screenshot 2026-05-31)
- [ ] **Invoke** with `claim_id: demo-1`, `content: SW.16 golden-path fixture` → Response tab shows `status: ok`
- [x] Screenshot → `evidence/SW16-grpcui-2026-05-31.png`
- [x] Manual PDF → `docs/CXR-GRPC-LAB-MANUAL.pdf`

## CXR placement (syllabus M2.8)

| Today (bootcamp) | Hypothetical gRPC boundary |
|------------------|----------------------------|
| Claim Studio **:3000** REST → `analyze/route.ts` → **spawn** Python | BFF → **ClaimAnalysis.AnalyzeClaim** → analysis kernel (no subprocess in Next) |
| GraphQL **:4000** external query API | gRPC = **internal** service-to-service (gateway ↔ kernel) |
| Kafka **:9092** async events | Complementary — publish after analyze, not replace gRPC sync path |

## Stop

```bash
docker compose -f compose.grpc.yaml down
```

## After SW.16

**SW.17 Vault** or **SW.18 Langfuse** on request.
