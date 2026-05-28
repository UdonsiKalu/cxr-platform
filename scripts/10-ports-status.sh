#!/usr/bin/env bash
set -euo pipefail
probe() {
  local port=$1 label=$2
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 1 "http://127.0.0.1:${port}/" 2>/dev/null || echo "000")
  if [[ "$code" == "000" ]]; then
    printf '  %-6s  down   %s\n' ":$port" "$label"
  else
    printf '  %-6s  HTTP %s  %s\n' ":$port" "$code" "$label"
  fi
}

echo "CXR port probe ($(date -Iseconds))"
probe 8251 "rehearsal (systemd)"
probe 3000 "compose lab (SW.2)"
probe 3002 "SW.1 Docker UI"
probe 6335 "Qdrant compose (/dashboard for UI)"
probe 8081 "K8 forward (SW.3)"
code=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 1 http://127.0.0.1:9090/-/ready 2>/dev/null || echo "000")
if [[ "$code" == "200" ]]; then printf '  %-6s  ready  Prometheus\n' ":9090"; else printf '  %-6s  down   Prometheus\n' ":9090"; fi
code=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 1 http://127.0.0.1:3001/api/health 2>/dev/null || echo "000")
if [[ "$code" == "200" ]]; then printf '  %-6s  HTTP 200  Grafana\n' ":3001"; else printf '  %-6s  down   Grafana\n' ":3001"; fi
probe 6333 "Qdrant host (optional)"
probe 9443 "Portainer"

echo ""
echo "systemd (user):"
for u in cxr-rehearsal-dev cxr-ops-lab-compose cxr-sw1-test cxr-k8-forward cxr-observe cxr-lab.target; do
  printf '  %-24s %s\n' "$u:" "$(systemctl --user is-active "$u" 2>/dev/null || echo n/a)"
done

echo ""
docker ps --format '  {{.Names}}  {{.Status}}  {{.Ports}}' 2>/dev/null | grep -E 'cxr-ops|cxr-sw1|cxr-lab|portainer|qdrant' || echo "  (no matching docker containers)"
