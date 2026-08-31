#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
USER_SYSTEMD="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
mkdir -p "$USER_SYSTEMD" "$USER_SYSTEMD/cxr-lab.target.wants"

echo "== CXR persistent ports (:8250 :8251 :8253–8256 :8262 :3000 :3002 :6335 :8081) + GPU watts =="
echo "Installing user systemd units..."
for u in \
  cxr-atlas-8250.service \
  cxr-ops-lab-compose.service \
  cxr-sw1-test.service \
  cxr-k8-forward.service \
  cxr-observe.service \
  n2s-lab-8253.service \
  n2s-panel-8254.service \
  n2s-safety-8255.service \
  n2s-repeng-8256.service \
  cxr-repeng-curriculum-8262.service \
  cxr-lab.target
do
  cp "$ROOT/systemd/$u" "$USER_SYSTEMD/"
done
chmod +x "$ROOT/../cxr-ui-prune-rehearsal/cxr-ui/scripts/run-atlas-8250.sh" 2>/dev/null || true
chmod +x "$ROOT/scripts/"*.sh 2>/dev/null || true

# Rehearsal unit may already exist; refresh only if missing
if [[ ! -f "$USER_SYSTEMD/cxr-rehearsal-dev.service" ]]; then
  cat >"$USER_SYSTEMD/cxr-rehearsal-dev.service" <<'UNIT'
[Unit]
Description=CXR rehearsal Next.js (port 8251)
After=network.target

[Service]
Type=simple
WorkingDirectory=/home/udonsi-kalu/staging/cxr-ui-prune-rehearsal/cxr-ui
Environment=PATH=/home/udonsi-kalu/.nvm/versions/node/v20.19.5/bin:/usr/local/bin:/usr/bin:/bin
Environment=NODE_ENV=development
ExecStart=/home/udonsi-kalu/.nvm/versions/node/v20.19.5/bin/npm run dev:rehearsal
Restart=always
RestartSec=5
StandardOutput=append:/tmp/cxr-rehearsal-8251.log
StandardError=append:/tmp/cxr-rehearsal-8251.log

[Install]
WantedBy=cxr-lab.target
UNIT
fi

# WantedBy symlinks for N2S + curriculum (target Wants= is enough; enable also links)
N2S_UNITS=(
  n2s-lab-8253.service
  n2s-panel-8254.service
  n2s-safety-8255.service
  n2s-repeng-8256.service
  cxr-repeng-curriculum-8262.service
)

loginctl enable-linger "$USER" 2>/dev/null || true
systemctl --user daemon-reload
systemctl --user enable cxr-lab.target
systemctl --user enable \
  cxr-atlas-8250.service \
  cxr-rehearsal-dev.service \
  cxr-ops-lab-compose.service \
  cxr-sw1-test.service \
  cxr-k8-forward.service \
  cxr-observe.service \
  "${N2S_UNITS[@]}"

echo "Starting cxr-lab.target (compose + SW.1 + K8 forward + N2S UIs; may take minutes on first boot)..."
systemctl --user start cxr-lab.target

echo ""
echo "== GPU power limit (system unit, Research 240 W) =="
if "$ROOT/scripts/09b-enable-gpu-power-limit.sh"; then
  echo "GPU power-limit unit installed."
else
  echo "WARN: GPU unit install failed or skipped — re-run: $ROOT/scripts/09b-enable-gpu-power-limit.sh"
fi

echo ""
"$ROOT/scripts/10-ports-status.sh"
echo ""
echo "Done. See $ROOT/docs/PERSISTENT-PORTS.md"
echo "Open Cursor workspace: /home/udonsi-kalu/staging (for .vscode port labels)"
