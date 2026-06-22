#!/usr/bin/env bash
# Raise Docker Desktop VM memory (Linux). Requires restart to take effect.
set -euo pipefail

TARGET_MIB="${1:-98304}"   # default 96 GiB
SETTINGS="${HOME}/.docker/desktop/settings-store.json"

if [[ ! -f "$SETTINGS" ]]; then
  echo "Docker Desktop settings not found: $SETTINGS" >&2
  exit 1
fi

echo "Stopping Docker Desktop before memory change..."
if command -v systemctl &>/dev/null && systemctl --user is-active docker-desktop &>/dev/null; then
  systemctl --user stop docker-desktop
  sleep 5
fi

python3 - <<PY
import json
from pathlib import Path
p = Path("$SETTINGS")
data = json.loads(p.read_text())
old = data.get("MemoryMiB", 0)
data["MemoryMiB"] = int("$TARGET_MIB")
p.write_text(json.dumps(data, indent=4) + "\n")
print(f"MemoryMiB: {old} -> {data['MemoryMiB']} ({data['MemoryMiB']/1024:.0f} GiB)")
PY

echo "Restarting Docker Desktop to apply memory..."
if command -v systemctl &>/dev/null; then
  systemctl --user start docker-desktop
elif pgrep -f "Docker Desktop" &>/dev/null; then
  killall "Docker Desktop" 2>/dev/null || true
  sleep 3
  nohup "/opt/docker-desktop/bin/docker-desktop" &>/dev/null &
else
  nohup "/opt/docker-desktop/bin/docker-desktop" &>/dev/null &
fi

echo "Wait for docker ready, then: kubectl get nodes"
