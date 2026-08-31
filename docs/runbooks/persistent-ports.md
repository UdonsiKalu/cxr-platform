# Persistent CXR ports + GPU watts (survive reboot + Cursor restart)

## What runs where

| Port | Service | Persistence |
|------|---------|-------------|
| **8250** | Atlas UI (`cxr-atlas-8250.service` → `next start`, rehearsal tree) | user systemd, `Restart=always` |
| **8251** | Rehearsal Next.js dev (`cxr-rehearsal-dev.service` → `next dev`) | user systemd, `Restart=always` |
| **8253** | N2S M1 lab (`n2s-lab-8253.service`) | user systemd |
| **8254** | N2S A–D panel (`n2s-panel-8254.service`) | user systemd |
| **8255** | N2S safety Ph5–7 (`n2s-safety-8255.service`) | user systemd |
| **8256** | Rep-Eng Workbench (`n2s-repeng-8256.service`, `.venv-phase9`) | user systemd |
| **8262** | Rep-Eng Curriculum (`cxr-repeng-curriculum-8262.service`) | user systemd |
| **3000** | Compose CXR UI (`cxr-ops-lab-compose.service`) | user systemd + `restart: unless-stopped` |
| **6335** | Compose Qdrant (`CXR_COMPOSE_QDRANT=1` on compose unit) | same stack as :3000 |
| **3002** | SW.1 UI (`cxr-sw1-test.service` → `cxr-sw1-test` container) | user systemd + Docker `unless-stopped` |
| **8081** | K8 port-forward (`cxr-k8-forward.service`) | user systemd `Restart=on-failure` + `12-k8-ensure.sh` |
| **9443** | Portainer | Docker `unless-stopped` (install once) |
| **6333** / **11434** / **1433** | Host Qdrant / Ollama / SQL | Your existing host services |

| GPU | Setting | Persistence |
|-----|---------|-------------|
| RTX 3090 | **`nvidia-smi -pl 240`** (Research) + persistence mode | system unit `nvidia-gpu-power-limit.service` |

All lab UI units are pulled in by **`cxr-lab.target`**.  
**Not auto-started:** Foundations Track **:8261** (parked).

Change boot watts: edit `/etc/default/nvidia-gpu-power-limit` (`WATTS=240|200|370`) then `sudo systemctl restart nvidia-gpu-power-limit`.

## One-time setup

```bash
cd /home/udonsi-kalu/staging/cxr-ops-lab
./scripts/09-enable-persistent-ports.sh
# GPU only (if ports already enabled):
./scripts/09b-enable-gpu-power-limit.sh
```

That enables **linger**, installs user systemd units, starts **`cxr-lab.target`**, installs the **system** GPU power-limit unit, and prints a port + GPU probe.

**First run** may take 10–20+ minutes if images or the kind cluster must be built.

## Cursor workspace

Open the **`staging`** folder (not only a subfolder).  
`staging/.vscode/settings.json` labels ports and sets **`remote.autoForwardPortsSource: hybrid`** so the **Ports** panel lists lab listeners when up.

Do **not** also run `npm run dev` / `npm run dev:rehearsal` in a terminal — systemd owns **8250** (prod `start`) and **8251** (dev). After UI code changes on **:8250**, run `npm run build` in `cxr-ui-prune-rehearsal/cxr-ui` then `systemctl --user restart cxr-atlas-8250`.

Close stale **Simple Browser** tabs on old localhost URLs if you see `GUEST_VIEW_MANAGER_CALL` / `ERR_CONNECTION_REFUSED` in the Cursor terminal (those are not IDE failures).

## Docker Desktop on Linux

`04-compose-up.sh` auto-selects **`compose.bridge.yaml`** (published **3000:3000**).  
Do **not** rely on `compose.host.yaml` on Desktop — `network_mode: host` binds inside the VM.

## Commands

```bash
systemctl --user status cxr-lab.target
systemctl --user restart cxr-lab.target
systemctl status nvidia-gpu-power-limit
journalctl --user -u n2s-repeng-8256 -f
./scripts/10-ports-status.sh
```

## Disable autostart

```bash
systemctl --user disable --now cxr-lab.target
sudo systemctl disable --now nvidia-gpu-power-limit
# Or individually:
systemctl --user disable --now cxr-k8-forward cxr-sw1-test cxr-ops-lab-compose cxr-rehearsal-dev \
  n2s-lab-8253 n2s-panel-8254 n2s-safety-8255 n2s-repeng-8256 cxr-repeng-curriculum-8262
```

## After reboot

```bash
/home/udonsi-kalu/staging/cxr-ops-lab/scripts/10-ports-status.sh
```

Expect **:8250–8256**, **:8262**, **:8251**, **:3000**, **:3002**, **:6335**, **:8081** without starting anything in Cursor, and GPU power limit **240 W**.
