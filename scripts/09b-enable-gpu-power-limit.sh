#!/usr/bin/env bash
# Install system unit so nvidia-smi -pl survives reboot (Research default 240 W).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UNIT_SRC="$ROOT/systemd/nvidia-gpu-power-limit.service"
DEFAULT_SRC="$ROOT/systemd/nvidia-gpu-power-limit.default"
UNIT_DST=/etc/systemd/system/nvidia-gpu-power-limit.service
DEFAULT_DST=/etc/default/nvidia-gpu-power-limit

if [[ ! -f "$UNIT_SRC" ]]; then
  echo "missing $UNIT_SRC" >&2
  exit 1
fi

if ! command -v nvidia-smi >/dev/null 2>&1; then
  echo "nvidia-smi not found — skip GPU power-limit unit" >&2
  exit 1
fi

sudo install -m 0644 "$UNIT_SRC" "$UNIT_DST"
sudo install -m 0644 "$DEFAULT_SRC" "$DEFAULT_DST"
sudo systemctl daemon-reload
sudo systemctl enable --now nvidia-gpu-power-limit.service

echo "GPU power limit:"
nvidia-smi --query-gpu=power.limit,persistence_mode --format=csv,noheader
systemctl is-enabled nvidia-gpu-power-limit.service
systemctl --no-pager -l status nvidia-gpu-power-limit.service | head -20
