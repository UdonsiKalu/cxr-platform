# Trivy Policy (SW.7)

## Scope
This policy applies to **Trivy image scans** run against locally built bootcamp images (primarily `cxr-ui:compose`, later `cxr-ui:local`) during the **SW.7** milestone.

## Rule of thumb (bootcamp vs production)
Bootcamp goal is **tracking and documentation**, not “zero CVEs”.

## Required outcomes for every Trivy scan
1. Save the scan output (table) plus a machine-readable report (`evidence/trivy-*.json`).
2. Record counts for **CRITICAL** and **HIGH** (and at least 3 example CVEs).
3. Decide a disposition:
   - **Track:** base image / transitive dependency CVEs you are not going to fix immediately.
   - **Fix:** CVEs that are directly caused by our app/runtime dependencies (acceptable fixes: base image bump, dependency bump, OS package bump).

## “Block vs warn” for CI (when we wire Trivy into GitHub Actions)
For bootcamp `cxr-ui-rehearsal` CI:
- **Warn only** (do not fail the workflow) while we are still iterating.
- The job should still *emit* the list and counts for review.

For later production hardening:
- Block merges on **CRITICAL**.
- For **HIGH**, block only if the fix is available and we own the vulnerable package (not purely transitive/base-image).

