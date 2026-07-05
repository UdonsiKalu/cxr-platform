#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
USER_SYSTEMD="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
mkdir -p "$USER_SYSTEMD"

echo "== CXR persistent ports (:8250 :8251 :3000 :3002 :6335 :8081 :9090 :3001) =="
echo "Installing user systemd units..."
cp "$ROOT/systemd/cxr-atlas-8250.service" "$USER_SYSTEMD/"
chmod +x "$ROOT/../cxr-ui-prune-rehearsal/cxr-ui/scripts/run-atlas-8250.sh" 2>/dev/null || true
cp "$ROOT/systemd/cxr-ops-lab-compose.service" "$USER_SYSTEMD/"
cp "$ROOT/systemd/cxr-sw1-test.service" "$USER_SYSTEMD/"
cp "$ROOT/systemd/cxr-k8-forward.service" "$USER_SYSTEMD/"
cp "$ROOT/systemd/cxr-observe.service" "$USER_SYSTEMD/"
cp "$ROOT/systemd/cxr-lab.target" "$USER_SYSTEMD/"
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

loginctl enable-linger "$USER" 2>/dev/null || true
systemctl --user daemon-reload
systemctl --user enable cxr-lab.target
systemctl --user enable cxr-atlas-8250.service cxr-rehearsal-dev.service cxr-ops-lab-compose.service cxr-sw1-test.service cxr-k8-forward.service cxr-observe.service

echo "Starting cxr-lab.target (compose + SW.1 + K8 forward; may take minutes on first boot)..."
systemctl --user start cxr-lab.target

echo ""
"$ROOT/scripts/10-ports-status.sh"
echo ""
echo "Done. See $ROOT/docs/runbooks/persistent-ports.md"
echo "Open Cursor workspace: /home/udonsi-kalu/staging (for .vscode port labels)"
