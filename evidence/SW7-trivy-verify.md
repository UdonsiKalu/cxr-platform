# SW.7 evidence — Trivy (local lab)

**Date:** 2026-05-26  
**Tool:** Trivy **0.70.0** (`~/.local/bin/trivy`)  
**Image:** `cxr-ui:compose` (SW.2 lab image)

## Install (one-time)

```bash
mkdir -p ~/.local/bin
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b ~/.local/bin
export PATH="$HOME/.local/bin:$PATH"
trivy --version
```

## Scan (repeat)

```bash
cd cxr-ops-lab
./scripts/08-trivy-scan.sh              # default cxr-ui:compose
./scripts/08-trivy-scan.sh cxr-ui:local # after SW.1 build
```

## First run summary (HIGH + CRITICAL)

| Severity | Count |
|----------|------:|
| CRITICAL | 9 |
| HIGH | 64 |

Bootcamp policy: **report and track** — many are base image / npm transitive; fix via `npm audit`, base image bumps, or accept with note. Exit code **0** = scan completed (not “zero CVEs”).

## Latest local scan (you just ran)
- **Date:** 2026-05-27
- **Image:** `cxr-ui:compose`
- **Observed:** new findings include (example) `CVE-2026-27601` (underscore example seen in console)
- **Counts:** CRITICAL `9`, HIGH `64` (matches earlier run)
- **Full JSON report exported to:** `evidence/trivy-cxr-ui-compose.json` (generated from Trivy `--format json` command)

## Not required

- GitHub Actions / remote **cxr-saas** workflow
- Deploy — Trivy only **scans** images already built locally
