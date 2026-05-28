# Persistent CXR ports (survive reboot + Cursor restart)

## What runs where

| Port | Service | Persistence |
|------|---------|-------------|
| **8251** | Rehearsal Next.js (`cxr-rehearsal-dev.service`) | user systemd, `Restart=always` |
| **3000** | Compose CXR UI (`cxr-ops-lab-compose.service`) | user systemd + `restart: unless-stopped` |
| **6335** | Compose Qdrant (`CXR_COMPOSE_QDRANT=1` on compose unit) | same stack as :3000 |
| **3002** | SW.1 UI (`cxr-sw1-test.service` → `cxr-sw1-test` container) | user systemd + Docker `unless-stopped` |
| **8081** | K8 port-forward (`cxr-k8-forward.service`) | user systemd `Restart=on-failure` + `12-k8-ensure.sh` |
| **9443** | Portainer | Docker `unless-stopped` (install once) |
| **6333** / **11434** / **1433** | Host Qdrant / Ollama / SQL | Your existing host services |

All lab units are pulled in by **`cxr-lab.target`**.

## One-time setup

```bash
cd /home/udonsi-kalu/staging/cxr-ops-lab
./scripts/09-enable-persistent-ports.sh
```

That enables **linger**, installs user systemd units, starts **`cxr-lab.target`**, and prints a port probe.

**First run** may take 10–20+ minutes if images or the kind cluster must be built.

## Cursor workspace

Open the **`staging`** folder (not only a subfolder).  
`staging/.vscode/settings.json` labels ports and sets **`remote.autoForwardPortsSource: hybrid`** so the **Ports** panel lists **8251**, **3000**, **3002**, **6335**, **8081** when listeners are up.

Do **not** also run `npm run dev:rehearsal` in a terminal — systemd owns **8251**.

Close stale **Simple Browser** tabs on old localhost URLs if you see `GUEST_VIEW_MANAGER_CALL` / `ERR_CONNECTION_REFUSED` in the Cursor terminal (those are not IDE failures).

## Docker Desktop on Linux

`04-compose-up.sh` auto-selects **`compose.bridge.yaml`** (published **3000:3000**).  
Do **not** rely on `compose.host.yaml` on Desktop — `network_mode: host` binds inside the VM.

## Commands

```bash
systemctl --user status cxr-lab.target
systemctl --user restart cxr-lab.target
journalctl --user -u cxr-k8-forward -f
journalctl --user -u cxr-ops-lab-compose -f
./scripts/10-ports-status.sh
```

## Disable autostart

```bash
systemctl --user disable --now cxr-lab.target
# Or individually:
systemctl --user disable --now cxr-k8-forward cxr-sw1-test cxr-ops-lab-compose cxr-rehearsal-dev
```

## After reboot

```bash
/home/udonsi-kalu/staging/cxr-ops-lab/scripts/10-ports-status.sh
```

Expect **:8251**, **:3000**, **:3002**, **:6335**, **:8081** HTTP responses without starting anything in Cursor.  
(**:6335** root may return **404**; use http://localhost:6335/dashboard .)
