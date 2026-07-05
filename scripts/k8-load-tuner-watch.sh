#!/usr/bin/env bash
# Live view of GATE-002 tuner: candidate milestones + current cumulative ramp.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${CXR_TUNER_OUTPUT_DIR:-$HOME/staging/cxr-portfolio/investigations/kubernetes-analyzer-saturation/results/tuner}"
MAIN_LOG="${CXR_TUNER_MAIN_LOG:-/tmp/cxr-load-tuner-run.log}"
INTERVAL="${CXR_TUNER_WATCH_INTERVAL:-10}"

latest_gate_log() {
  ls -t "$OUT"/run-*/gate-c*.log 2>/dev/null | head -1 || true
}

latest_stamp() {
  basename "$(dirname "$(latest_gate_log)")" 2>/dev/null | sed -n 's/run-\(.*\)-c\([0-9]*\)/stamp=\1 candidate=\2/p' || true
}

header() {
  echo "══════════════════════════════════════════════════════════════"
  echo "  CXR load tuner watch  —  $(date '+%Y-%m-%d %H:%M:%S')"
  echo "  Output: $OUT"
  echo "  Main:   $MAIN_LOG"
  echo "══════════════════════════════════════════════════════════════"
  if pgrep -f 'k8-load-tuner.sh' >/dev/null 2>&1; then
    echo "  Status: RUNNING"
  else
    echo "  Status: not running (finished or stopped)"
  fi
  local meta
  meta="$(latest_stamp)"
  [[ -n "$meta" ]] && echo "  Active: $meta"
  echo ""
}

section() {
  echo "── $1 ──"
}

usage() {
  cat <<EOF
Usage: $0 [--follow] [--once]

  CXR_TUNER_OUTPUT_DIR     Results dir (default: portfolio .../results/tuner)
  CXR_TUNER_MAIN_LOG       Main log (default: /tmp/cxr-load-tuner-run.log)
  CXR_TUNER_WATCH_INTERVAL Refresh seconds (default: 10)

  --follow   Refresh until Ctrl+C (default)
  --once     Print one snapshot and exit
EOF
}

MODE=follow
while [[ $# -gt 0 ]]; do
  case "$1" in
    --once) MODE=once ;;
    --follow) MODE=follow ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown: $1" >&2; usage; exit 1 ;;
  esac
  shift
done

snapshot() {
  header

  section "Candidate progress (main log)"
  if [[ -f "$MAIN_LOG" ]]; then
    grep -E '^(===|== Candidate|TUNER COMPLETE|Winner|  "score"|  "all_pass")' "$MAIN_LOG" 2>/dev/null | tail -20 || true
  else
    echo "  (no main log yet)"
  fi
  echo ""

  section "Scored results (newest first)"
  if ls "$OUT"/result-c*.json >/dev/null 2>&1; then
    ls -lt "$OUT"/result-c*.json 2>/dev/null | head -8 | awk '{print "  " $6, $7, $8, $9}'
  else
    echo "  (none yet)"
  fi
  echo ""

  local gate
  gate="$(latest_gate_log)"
  section "Live cumulative ramp"
  if [[ -n "$gate" && -f "$gate" ]]; then
    echo "  $gate"
    echo ""
    grep -E 'Cumulative ramp|Checkpoint|users=|GATE PASSED|GATE FAILED|\[PASS\]|\[FAIL\]' "$gate" 2>/dev/null | tail -25 || true
    echo ""
    tail -8 "$gate" 2>/dev/null || true
  else
    echo "  (waiting for gate log — between candidates or not started)"
  fi
  echo ""

  local summary
  summary="$(ls -t "$OUT"/tuner-summary-*.json 2>/dev/null | head -1 || true)"
  if [[ -n "$summary" && -f "$summary" ]]; then
    section "Winner"
    head -30 "$summary"
  fi
}

if [[ "$MODE" == "once" ]]; then
  snapshot
  exit 0
fi

echo "Refreshing every ${INTERVAL}s — Ctrl+C to stop"
echo "Tip: in another terminal: tail -f $MAIN_LOG"
echo ""
while true; do
  if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
    tput clear 2>/dev/null || clear
  else
    echo ""
    echo "──────── refresh $(date '+%H:%M:%S') ────────"
  fi
  snapshot
  sleep "$INTERVAL"
done
