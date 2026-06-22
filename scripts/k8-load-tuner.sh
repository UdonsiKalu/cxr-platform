#!/usr/bin/env bash
# GATE-002 — Search Helm parameters; score with k8-load-gate.sh + tuner_config.yaml.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/bin:${PATH:-}"
# shellcheck source=lib/kind-common.sh
source "$ROOT/scripts/lib/kind-common.sh"

CONFIG="${CXR_TUNER_CONFIG:-$ROOT/tuner_config.yaml}"
NS="${CXR_K8_NAMESPACE:-cxr-ui}"
OUT_DIR="${CXR_TUNER_OUTPUT_DIR:-/tmp/cxr-load-tuner}"
STAMP="$(date +%Y%m%d-%H%M%S)"
HOST_VALUES="$(mktemp /tmp/cxr-tuner-host-XXXXXX.yaml)"
trap 'rm -f "$HOST_VALUES"' EXIT

usage() {
  cat <<EOF
Usage: $0 [--dry-run] [--limit N]

  CXR_TUNER_CONFIG   Path to tuner_config.yaml (default: repo root)
  CXR_TUNER_OUTPUT_DIR  Reports directory (default: /tmp/cxr-load-tuner)

Grid-searches Helm values, runs k8-load-gate.sh per candidate, picks lowest score.
EOF
}

DRY_RUN=0
LIMIT=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --limit) LIMIT="${2:-0}"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

require_kubectl "$ROOT"
python3 -c "import yaml" 2>/dev/null || pip install -q pyyaml

mkdir -p "$OUT_DIR"
cat >"$HOST_VALUES" <<EOF
env:
  CXR_SQL_SERVER: "host.docker.internal,1433"
  CXR_QDRANT_URL: "http://host.docker.internal:6333"
EOF

suspend_argo() {
  kubectl patch application cxr-analyzer -n argocd --type merge \
    -p '{"spec":{"syncPolicy":{"automated": null}}}' 2>/dev/null || true
}

apply_candidate() {
  local id="$1"
  local candidate_file="$2"
  echo "== Candidate $id =="
  cat "$candidate_file"
  if [[ "$DRY_RUN" -eq 1 ]]; then
    return 0
  fi
  suspend_argo
  kubectl delete hpa cxr-analyzer -n cxr-ui --ignore-not-found 2>/dev/null || true

  local -a analyzer_sets=()
  local -a ui_sets=()
  python3 - <<PY
import json
from pathlib import Path
c = json.loads(Path("$candidate_file").read_text())
for k, v in c.items():
    if k.startswith("analyzer."):
        key = k.replace("analyzer.", "", 1)
        print(f"ANALYZER {key}={v}")
    elif k.startswith("ui."):
        key = k.replace("ui.", "", 1)
        print(f"UI {key}={v}")
PY
  while read -r line; do
    [[ -z "$line" ]] && continue
    kind="${line%% *}"
    rest="${line#* }"
    if [[ "$kind" == "ANALYZER" ]]; then
      analyzer_sets+=(--set "$rest")
    else
      ui_sets+=(--set "$rest")
    fi
  done < <(python3 - <<PY
import json
from pathlib import Path
c = json.loads(Path("$candidate_file").read_text())
for k, v in c.items():
    if k.startswith("analyzer."):
        print(f"ANALYZER {k.replace('analyzer.', '', 1)}={v}")
    elif k.startswith("ui."):
        print(f"UI {k.replace('ui.', '', 1)}={v}")
PY
)

  helm upgrade --install cxr-analyzer "$ROOT/helm/cxr-analyzer" -n "$NS" \
    -f "$HOST_VALUES" "${analyzer_sets[@]}" --timeout 5m
  if [[ ${#ui_sets[@]} -gt 0 ]]; then
    helm upgrade --install cxr-ui "$ROOT/helm/cxr-ui" -n "$NS" \
      "${ui_sets[@]}" --timeout 5m
  fi
  kubectl rollout status deployment/cxr-analyzer -n "$NS" --timeout=600s
  if ! kubectl wait --for=condition=ready pod -l app=cxr-analyzer -n "$NS" --timeout=600s; then
    echo "WARN: analyzer pod ready wait timed out — continuing gate (pods may still be warming)" >&2
    kubectl get pods -n "$NS" -l app=cxr-analyzer >&2 || true
  fi
}

run_gate() {
  local id="$1"
  local gate_dir="$OUT_DIR/run-${STAMP}-c${id}"
  mkdir -p "$gate_dir"
  export CXR_GATE_OUTPUT_DIR="$gate_dir"

  eval "$(python3 - <<PY
import shlex
import yaml
from pathlib import Path
c = yaml.safe_load(Path("$CONFIG").read_text())
lt = c.get("load_target") or {}
slos = c.get("slos") or {}
mode = lt.get("mode", "discrete_stages")
if mode == "cumulative_ramp":
    mode = "cumulative"
else:
    mode = "discrete"
pairs = {
    "CXR_GATE_MODE": mode,
    "CXR_RAMP_PROFILE": str(lt.get("profile", "lightweight_mixed")),
    "CXR_GATE_SPAWN_RATE": str(lt.get("spawn_rate", 5)),
    "CXR_GATE_STAGE_TIME": str(lt.get("stage_time", "90s")),
    "CXR_GATE_RAMP_START": str(lt.get("ramp_start", 25)),
    "CXR_GATE_RAMP_STEP": str(lt.get("ramp_step", 25)),
    "CXR_GATE_RAMP_MAX": str(lt.get("ramp_max", 200)),
    "CXR_GATE_RAMP_HOLD": str(lt.get("hold_at_max", "2m")),
    "CXR_GATE_MAX_COLLAPSES": str(slos.get("max_collapses", 0)),
    "CXR_GATE_MAX_FAILURES": str(slos.get("max_failures_per_s", 0.5)),
}
cps = lt.get("score_checkpoints")
if cps:
    pairs["CXR_GATE_SCORE_CHECKPOINTS"] = " ".join(str(x) for x in cps)
stages = lt.get("stages")
if stages:
    pairs["CXR_GATE_STAGES"] = " ".join(str(x) for x in stages)
soft = lt.get("soft_final_stage_users")
if soft:
    pairs["CXR_GATE_SOFT_200"] = "1"
for k, v in pairs.items():
    print(f"export {k}={shlex.quote(v)}")
PY
)"

  local gate_rc=0
  local gate_log="$gate_dir/gate-c${id}.log"
  local gate_args=(--skip-preflight)
  [[ "${CXR_GATE_MODE:-}" == "cumulative" ]] && gate_args+=(--cumulative)
  [[ "${CXR_GATE_SOFT_200:-}" == "1" && "${CXR_GATE_MODE:-}" != "cumulative" ]] && gate_args+=(--soft-200)

  "$ROOT/scripts/k8-load-gate.sh" "${gate_args[@]}" >"$gate_log" 2>&1 || gate_rc=$?

  local report
  report="$(ls -t "$gate_dir"/gate-report-*.json 2>/dev/null | head -1)"
  if [[ -z "$report" || ! -s "$report" ]]; then
    echo '{"score": 999999, "all_pass": false, "error": "no gate report", "gate_log": "'"$gate_log"'"}'
    return 0
  fi
  python3 "$ROOT/scripts/lib/load_tuner.py" "$CONFIG" --score-report "$report"
  return 0
}

main() {
  echo "== GATE-002 load tuner =="
  echo "  config=$CONFIG"
  echo "  output=$OUT_DIR"
  echo ""

  if [[ "$DRY_RUN" -eq 0 ]]; then
    "$ROOT/scripts/23-k8-load-observe-up.sh" || true
    "$ROOT/scripts/k8-load-exporter.sh" start || true
  fi

  local candidates_dir="$OUT_DIR/candidates-${STAMP}"
  mkdir -p "$candidates_dir"
  python3 "$ROOT/scripts/lib/load_tuner.py" "$CONFIG" --list-candidates >"$candidates_dir/all.jsonl"

  local best_id="" best_score="inf" best_file="" best_result=""
  local count=0
  while read -r line; do
    [[ -z "$line" ]] && continue
    id="$(echo "$line" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")"
    if [[ "$LIMIT" -gt 0 && "$count" -ge "$LIMIT" ]]; then
      break
    fi
    cand_file="$candidates_dir/candidate-${id}.json"
    echo "$line" | python3 -c "import json,sys; print(json.dumps(json.load(sys.stdin)['candidate']))" >"$cand_file"

    apply_candidate "$id" "$cand_file"
    if [[ "$DRY_RUN" -eq 1 ]]; then
      count=$((count + 1))
      continue
    fi
    result="$(run_gate "$id")"
    echo "$result" | tee "$OUT_DIR/result-c${id}-${STAMP}.json"
    score="$(echo "$result" | python3 -c "import json,sys; print(json.load(sys.stdin)['score'])")"
    if python3 -c "print(1 if float('$score') < float('${best_score:-inf}') else 0)" | grep -q 1; then
      best_score="$score"
      best_id="$id"
      best_file="$cand_file"
      best_result="$result"
    fi
    count=$((count + 1))
  done < "$candidates_dir/all.jsonl"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "DRY RUN: $(wc -l < "$candidates_dir/all.jsonl") candidates listed in $candidates_dir"
    exit 0
  fi

  local summary="$OUT_DIR/tuner-summary-${STAMP}.json"
  if [[ -n "$best_id" && -f "$OUT_DIR/result-c${best_id}-${STAMP}.json" ]]; then
    python3 - <<PY >"$summary"
import json
from pathlib import Path
best_result = json.loads(Path("$OUT_DIR/result-c${best_id}-${STAMP}.json").read_text())
best_candidate = json.loads(Path("$best_file").read_text())
print(json.dumps({
    "stamp": "$STAMP",
    "best_id": int("$best_id"),
    "best_score": best_result.get("score"),
    "all_pass": best_result.get("all_pass"),
    "best_candidate": best_candidate,
    "best_result": best_result,
}, indent=2))
PY
    apply_candidate "$best_id" "$best_file"
    echo "Winner candidate $best_id applied."
  else
    echo '{"error": "no successful candidate"}' >"$summary"
  fi

  echo ""
  echo "== TUNER COMPLETE =="
  cat "$summary"
}

main "$@"
