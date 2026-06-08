# SW.15 — GraphQL verify (2026-05-31)

## Stack

| URL | Service |
|-----|---------|
| http://localhost:4000/graphql | **Apollo Gateway** (federated entry + Sandbox UI) |
| http://localhost:4001/graphql | **Claims subgraph** (CXR `Claim` type) |
| http://localhost:4002/graphql | **Policies subgraph** (mock `Policy`) |

## Commands

```bash
./scripts/18-graphql-up.sh
./scripts/18-graphql-smoke.sh
```

## Golden query

See `lab/graphql/query-golden.graphql` — `claim(demo-1)` + `policyForClaim`.

## Checklist

- [x] `./scripts/18-graphql-smoke.sh` → federated `status: ok` + `CXR-POL-OK`
- [x] Browser Sandbox at :4000 runs golden query (`Sw15GoldenPath`, **200**)
- [x] Screenshot **`evidence/SW15-graphql-sandbox-2026-05-31.png`**

## Not wired

- **Claim Studio :3000** uses REST — GraphQL lab is standalone (syllabus pattern).

## User verify (2026-05-31)

- Apollo Sandbox **http://localhost:4000/graphql** — `claim(demo-1)` → `status: ok`, `summary: SW.15 GraphQL lab…`; `policyForClaim` → `CXR-POL-OK`

## Agent verify (2026-05-31)

- `./scripts/18-graphql-up.sh` — gateway + claims + policies containers healthy
- `./scripts/18-graphql-smoke.sh` — OK federated response
- PDF: `docs/CXR-GRAPHQL-LAB-MANUAL.pdf`

## Next syllabus

**SW.16 gRPC** sketch.
