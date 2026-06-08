#!/usr/bin/env bash
# Enable Docker Desktop Kubernetes and switch kubectl to docker-desktop context.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/bin:${PATH:-}"
SETTINGS="$HOME/.docker/desktop/settings-store.json"

echo "=== CXR — Docker Desktop Kubernetes enable ==="

if ! docker desktop status 2>/dev/null | grep -qi 'running'; then
  echo "Starting Docker Desktop..."
  docker desktop start
  for _ in $(seq 1 60); do
    docker desktop status 2>/dev/null | grep -qi 'running' && break
    sleep 2
  done
fi

python3 - <<'PY'
import json, os
path = os.path.expanduser("~/.docker/desktop/settings-store.json")
data = {}
if os.path.isfile(path):
    with open(path) as f:
        data = json.load(f)
changed = False
for key, val in [("kubernetesEnabled", True), ("memoryMiB", 32768)]:
    if data.get(key) != val:
        data[key] = val
        changed = True
if changed:
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    print("Updated settings-store.json: kubernetesEnabled=true, memoryMiB=32768")
else:
    print("settings-store.json already has kubernetesEnabled + memoryMiB=32768")
PY

status="$(docker desktop kubernetes status 2>/dev/null | awk '/^State:/ {print $2}' || true)"
if [[ "$status" != "running" && "$status" != "enabled" ]]; then
  echo "Restarting Docker Desktop to start Kubernetes (may take 1–3 min)..."
  docker desktop restart
  for _ in $(seq 1 90); do
    st="$(docker desktop kubernetes status 2>/dev/null | awk '/^State:/ {print $2}' || true)"
    if [[ "$st" == "running" ]]; then
      break
    fi
    sleep 2
  done
fi

echo ""
docker desktop kubernetes status 2>/dev/null || true

if ! kubectl config get-contexts -o name 2>/dev/null | grep -qx 'docker-desktop'; then
  echo "ERROR: docker-desktop context not in kubeconfig after enable." >&2
  echo "  Open Docker Desktop → Settings → Kubernetes → Enable → Apply & Restart" >&2
  exit 1
fi

kubectl config use-context docker-desktop
kubectl get nodes -o wide

echo ""
echo "Docker Desktop Kubernetes ready (context: docker-desktop)."
echo "  Next: CXR_SKIP_ANALYZER_BUILD=1 $ROOT/scripts/03-k8-desktop-stack-up.sh"
