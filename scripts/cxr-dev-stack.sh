#!/usr/bin/env bash
# CXR local dev stack — one command for Claim Studio + Jaeger + Locust (+ optional labs).
#
#   ~/staging/cxr-dev.sh up       # observe + :8766 + :8251 + Locust :8089
#   ~/staging/cxr-dev.sh down
#   ~/staging/cxr-dev.sh lab list
#   ~/staging/cxr-dev.sh lab up kafka
#
set -euo pipefail

OPS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGING_ROOT="$(cd "${OPS_ROOT}/.." && pwd)"
CAT_ROOT="${CXR_CLAIM_ANALYSIS_TOOLS:-${STAGING_ROOT}/cxrlabs-dev/claim_analysis_tools}"
UI_ROOT="${CXR_UI_REHEARSAL:-${STAGING_ROOT}/cxr-ui-prune-rehearsal/cxr-ui}"

ANALYZER_PORT="${CXR_ANALYZER_PORT:-8766}"
REHEARSAL_PORT="${CXR_REHEARSAL_PORT:-8251}"
LOCUST_PORT="${CXR_LOCUST_WEB_PORT:-8089}"
ANALYZER_URL="http://127.0.0.1:${ANALYZER_PORT}"
REHEARSAL_URL="http://127.0.0.1:${REHEARSAL_PORT}"
LOCUST_URL="http://127.0.0.1:${LOCUST_PORT}"
JAEGER_URL="${CXR_JAEGER_UI:-http://127.0.0.1:16686}"
OTEL_ENDPOINT="${OTEL_EXPORTER_OTLP_ENDPOINT:-http://127.0.0.1:4318}"
CXR_LOAD_URL="${CXR_LOAD_URL:-${REHEARSAL_URL}}"

LOG_ANALYZER="/tmp/cxr-analyzer-service.log"
LOG_REHEARSAL="/tmp/cxr-rehearsal-${REHEARSAL_PORT}.log"
LOG_LOCUST="/tmp/cxr-locust-${LOCUST_PORT}.log"

# Optional syllabus labs (each has *-up.sh; down via compose file)
LAB_NAMES=(kafka elk redis graphql grpc vault langfuse)
declare -A LAB_UP=(
  [kafka]=06-kafka-up.sh
  [elk]=16-elk-up.sh
  [redis]=17-redis-up.sh
  [graphql]=18-graphql-up.sh
  [grpc]=19-grpc-up.sh
  [vault]=20-vault-up.sh
  [langfuse]=21-langfuse-up.sh
)
declare -A LAB_COMPOSE=(
  [kafka]="$OPS_ROOT/compose/labs/kafka.yaml"
  [elk]="$OPS_ROOT/compose/labs/elk.yaml"
  [redis]="$OPS_ROOT/compose/labs/redis.yaml"
  [graphql]="$OPS_ROOT/compose/labs/graphql.yaml"
  [grpc]="$OPS_ROOT/compose/labs/grpc.yaml"
  [vault]="$OPS_ROOT/compose/labs/vault.yaml"
  [langfuse]="$OPS_ROOT/compose/labs/langfuse.yaml"
)
declare -A LAB_NOTE=(
  [kafka]="UI :8082  broker :9092"
  [elk]="Kibana :5601  ES :9200"
  [redis]="Redis :6379  Insight :5540"
  [graphql]="Sandbox :4000"
  [grpc]="grpcui :8083"
  [vault]="Vault :8200"
  [langfuse]="Langfuse :3100"
)

usage() {
  cat <<EOF
Usage: $(basename "$0") <command> [options]

Daily dev (Claim Studio + traces + load):
  up        Observe (Jaeger) if down + analyzer :${ANALYZER_PORT} + rehearsal :${REHEARSAL_PORT} + Locust :${LOCUST_PORT}
  down      Stop Locust, rehearsal, analyzer (not Docker observe by default)
  restart   down + up
  status    Health + ports
  logs      tail analyzer + rehearsal + locust logs

Options (up/down/restart):
  --no-observe     Skip docker observe on 'up'
  --no-load        Skip Locust on 'up' / do not stop Locust on 'down'
  --observe-down   Also stop Jaeger/Prometheus/Grafana on 'down'

Optional syllabus labs (Kafka, ELK, Redis, …):
  lab list              Table of labs + scripts
  lab up <name>         Run cxr-ops-lab/scripts/*-up.sh
  lab down <name>       docker compose -f compose/labs/<name>.yaml down

URLs after 'up':
  Claim Studio  ${REHEARSAL_URL}/claim-studio
  Locust        ${LOCUST_URL}  (target ${CXR_LOAD_URL})
  Jaeger        ${JAEGER_URL}

Logs: ${LOG_ANALYZER}  ${LOG_REHEARSAL}  ${LOG_LOCUST}
EOF
}

port_pid() {
  local port="$1"
  fuser "${port}/tcp" 2>/dev/null | awk '{print $NF}' | head -1 || true
}

http_ok() {
  curl -sf -m 3 -o /dev/null "$1" 2>/dev/null
}

wait_http() {
  local url="$1" label="$2" max="${3:-60}"
  local i
  for ((i = 1; i <= max; i++)); do
    if http_ok "$url"; then
      echo "OK  ${label}"
      return 0
    fi
    sleep 2
  done
  echo "FAIL ${label} (${url}) — see logs" >&2
  return 1
}

compose_dc() {
  if command -v docker-compose &>/dev/null; then
    echo docker-compose
  else
    echo "docker compose"
  fi
}

cmd_status() {
  echo "== CXR dev stack status =="
  if http_ok "${JAEGER_URL}/"; then
    echo "Jaeger/OTLP   UP   ${JAEGER_URL}  (OTLP ${OTEL_ENDPOINT})"
  else
    echo "Jaeger/OTLP   DOWN ${JAEGER_URL}"
  fi
  if http_ok "${ANALYZER_URL}/health"; then
    local warmed
    warmed="$(curl -sf "${ANALYZER_URL}/health" | grep -o '"warmed":"[^"]*"' || true)"
    echo "Analyzer      UP   ${ANALYZER_URL}/health  ${warmed}  pid=$(port_pid "${ANALYZER_PORT}")"
  else
    echo "Analyzer      DOWN :${ANALYZER_PORT}"
  fi
  if http_ok "${REHEARSAL_URL}/claim-studio"; then
    echo "Rehearsal     UP   ${REHEARSAL_URL}/claim-studio  pid=$(port_pid "${REHEARSAL_PORT}")"
  else
    echo "Rehearsal     DOWN :${REHEARSAL_PORT}"
  fi
  if http_ok "${LOCUST_URL}/"; then
    echo "Locust        UP   ${LOCUST_URL}  → ${CXR_LOAD_URL}  pid=$(port_pid "${LOCUST_PORT}")"
  else
    echo "Locust        DOWN :${LOCUST_PORT}"
  fi
}

start_observe() {
  if http_ok "${JAEGER_URL}/"; then
    echo "Observe already up (${JAEGER_URL})"
    return 0
  fi
  echo "Starting observe (Jaeger, OTLP, Prometheus, Grafana)..."
  timeout 120 "${OPS_ROOT}/scripts/07-observe-up.sh" || {
    echo "WARN: observe up slow/failed" >&2
    return 1
  }
}

start_analyzer() {
  if http_ok "${ANALYZER_URL}/health"; then
    echo "Analyzer already up (${ANALYZER_URL})"
    return 0
  fi
  if [[ -n "$(port_pid "${ANALYZER_PORT}")" ]]; then
    echo "Port :${ANALYZER_PORT} busy but unhealthy — run: $(basename "$0") down" >&2
    return 1
  fi
  echo "Starting analyzer :${ANALYZER_PORT} → ${LOG_ANALYZER}"
  (
    export OTEL_EXPORTER_OTLP_ENDPOINT="${OTEL_ENDPOINT}"
    export OTEL_SERVICE_NAME="${OTEL_SERVICE_NAME:-cxr-analyzer-service}"
    export CXR_TRACE_PROFILE="${CXR_TRACE_PROFILE:-detailed}"
    cd "${CAT_ROOT}"
    nohup ./scripts/start_analyzer_service.sh >>"${LOG_ANALYZER}" 2>&1 &
  )
  wait_http "${ANALYZER_URL}/health" "analyzer" 120
}

start_rehearsal() {
  if http_ok "${REHEARSAL_URL}/claim-studio"; then
    echo "Rehearsal already up (${REHEARSAL_URL})"
    return 0
  fi
  if [[ -n "$(port_pid "${REHEARSAL_PORT}")" ]]; then
    echo "Port :${REHEARSAL_PORT} busy but unhealthy — run: $(basename "$0") down" >&2
    return 1
  fi
  if ! http_ok "${ANALYZER_URL}/health"; then
    echo "ERROR: analyzer required (${ANALYZER_URL}/health)" >&2
    return 1
  fi
  echo "Starting rehearsal :${REHEARSAL_PORT} → ${LOG_REHEARSAL}"
  nohup "${UI_ROOT}/scripts/run-rehearsal-dev.sh" >>"${LOG_REHEARSAL}" 2>&1 &
  wait_http "${REHEARSAL_URL}/claim-studio" "rehearsal" 90
}

start_locust() {
  if http_ok "${LOCUST_URL}/"; then
    echo "Locust already up (${LOCUST_URL})"
    return 0
  fi
  if ! http_ok "${REHEARSAL_URL}/claim-studio"; then
    echo "ERROR: rehearsal required before Locust (${REHEARSAL_URL})" >&2
    return 1
  fi
  local locust_dir="${OPS_ROOT}/load/locust"
  local venv="${locust_dir}/.venv"
  if [[ ! -d "${venv}" ]]; then
    echo "Creating Locust venv..."
    python3 -m venv "${venv}"
    "${venv}/bin/pip" install -q --upgrade pip
    "${venv}/bin/pip" install -q -r "${locust_dir}/requirements.txt"
  fi
  echo "Starting Locust :${LOCUST_PORT} → ${CXR_LOAD_URL}  log ${LOG_LOCUST}"
  (
    export CXR_LOAD_URL
    export CXR_LOCUST_WEB_PORT="${LOCUST_PORT}"
    cd "${OPS_ROOT}"
    nohup "${venv}/bin/locust" \
      -f "${locust_dir}/locustfile.py" \
      --host "${CXR_LOAD_URL}" \
      --web-host 127.0.0.1 \
      --web-port "${LOCUST_PORT}" >>"${LOG_LOCUST}" 2>&1 &
  )
  wait_http "${LOCUST_URL}/" "locust" 30
}

stop_locust() {
  fuser -k "${LOCUST_PORT}/tcp" 2>/dev/null && echo "Stopped Locust :${LOCUST_PORT}" || echo "Locust :${LOCUST_PORT} not running"
}

parse_app_flags() {
  WITH_OBSERVE=1
  WITH_LOAD=1
  OBSERVE_DOWN=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-observe) WITH_OBSERVE=0 ;;
      --no-load) WITH_LOAD=0 ;;
      --observe-down) OBSERVE_DOWN=1 ;;
      *)
        echo "Unknown option: $1" >&2
        usage
        exit 1
        ;;
    esac
    shift
  done
}

cmd_up() {
  parse_app_flags "$@"
  echo "== CXR dev stack up =="
  [[ "${WITH_OBSERVE}" -eq 1 ]] && start_observe || true
  start_analyzer
  start_rehearsal
  [[ "${WITH_LOAD}" -eq 1 ]] && start_locust
  echo ""
  cmd_status
  echo ""
  echo "Claim Studio  ${REHEARSAL_URL}/claim-studio"
  echo "Locust        ${LOCUST_URL}  (Start swarming in UI)"
  echo "Jaeger        ${JAEGER_URL}"
}

cmd_down() {
  parse_app_flags "$@"
  echo "== CXR dev stack down =="
  [[ "${WITH_LOAD}" -eq 1 ]] && stop_locust
  fuser -k "${REHEARSAL_PORT}/tcp" 2>/dev/null && echo "Stopped rehearsal :${REHEARSAL_PORT}" || true
  fuser -k "${ANALYZER_PORT}/tcp" 2>/dev/null && echo "Stopped analyzer :${ANALYZER_PORT}" || true
  sleep 1
  [[ "${OBSERVE_DOWN}" -eq 1 ]] && "${OPS_ROOT}/scripts/07-observe-down.sh" || true
  cmd_status
}

cmd_logs() {
  touch "${LOG_ANALYZER}" "${LOG_REHEARSAL}" "${LOG_LOCUST}"
  tail -f "${LOG_ANALYZER}" "${LOG_REHEARSAL}" "${LOG_LOCUST}"
}

cmd_lab_list() {
  echo "== Optional CXR labs (cxr-ops-lab) =="
  echo "Not started by 'cxr up' except observe/Jaeger. Use: $(basename "$0") lab up <name>"
  echo ""
  printf "%-10s %-22s %s\n" "NAME" "UP SCRIPT" "NOTES"
  for name in "${LAB_NAMES[@]}"; do
    printf "%-10s %-22s %s\n" "${name}" "${LAB_UP[$name]}" "${LAB_NOTE[$name]}"
  done
  echo ""
  echo "Also: compose :3000 → ./scripts/04-compose-up.sh  |  K8 → ./scripts/03-k8-up.sh"
}

cmd_lab_up() {
  local name="${1:-}"
  if [[ -z "${name}" ]] || [[ -z "${LAB_UP[$name]:-}" ]]; then
    echo "Usage: $(basename "$0") lab up <name>" >&2
    cmd_lab_list
    exit 1
  fi
  "${OPS_ROOT}/scripts/${LAB_UP[$name]}"
}

cmd_lab_down() {
  local name="${1:-}"
  if [[ -z "${name}" ]] || [[ -z "${LAB_COMPOSE[$name]:-}" ]]; then
    echo "Usage: $(basename "$0") lab down <name>" >&2
    exit 1
  fi
  local dc
  dc="$(compose_dc)"
  cd "${OPS_ROOT}"
  ${dc} -f "${LAB_COMPOSE[$name]}" down
  echo "Stopped lab: ${name}"
}

cmd_lab() {
  local sub="${1:-list}"
  shift || true
  case "${sub}" in
    list) cmd_lab_list ;;
    up) cmd_lab_up "$@" ;;
    down) cmd_lab_down "$@" ;;
    *)
      echo "Usage: $(basename "$0") lab {list|up|down} [name]" >&2
      exit 1
      ;;
  esac
}

main() {
  local cmd="${1:-}"
  shift || true
  case "${cmd}" in
    up) cmd_up "$@" ;;
    down) cmd_down "$@" ;;
    restart) cmd_down "$@"; sleep 2; cmd_up "$@" ;;
    status) cmd_status ;;
    logs) cmd_logs ;;
    lab) cmd_lab "$@" ;;
    -h|--help|help|"") usage ;;
    *) echo "Unknown command: ${cmd}" >&2; usage; exit 1 ;;
  esac
}

main "$@"
