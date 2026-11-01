---
name: paseo-daemon-keepalive
description: "Diagnose and fix a self-hosted Paseo daemon (or its agents) appearing to stop/stall on a Linux laptop — suspend/lock, session-scope death, relay reconnect storms — and make the daemon survive as a systemd user service."
---

# Diagnosing "Paseo stops when I lock my screen"

Applies to self-hosted Paseo on Linux (Hyprland/GNOME/etc.). Symptom: agents freeze or the app can't reach the daemon after the screen lock.

## 1. Establish topology first

```bash
paseo --version; paseo daemon status --json   # owner, pid, home, listen, logPath, desktopManaged
ps -o pid,ppid,etimes,args -p <supervisorPid>
cat /proc/<supervisorPid>/cgroup               # paseo.service vs kitty-*.scope / session-N.scope
```

- `desktopManaged: false` → standalone/npm daemon (or Docker); its lifetime is whoever started it.
- Daemon in a terminal/session scope dies when that scope is torn down; daemon in `paseo.service` is a real service.

## 2. Prove whether it was frozen, killed, or restarted

- `~/.paseo/daemon.log` (or `$PASEO_HOME/daemon.log`) emits `ws_runtime_metrics` every 30 s. **A multi-minute hole in that cadence = the process was frozen (suspend) or gone.**
- Confirm suspend: `journalctl -b | grep -E "PM: suspend entry|PM: suspend exit|Reached target Sleep"`, and `journalctl -b -2` for earlier boots.
- Graceful client-initiated stops show as `client_shutdown_rpc` / `shutdown_server_request`; crashes as `Worker exited` with non-zero code, or a fresh `Starting daemon worker` line.
- Post-resume signature: `relay_control_stale_terminating` then a long `relay_error` / `relay_control_disconnected (code 1006)` storm — remote clients see "stopped" even though the daemon is alive.

## 3. Check the machine's idle chain

```bash
grep -n -A3 listener ~/.config/hypr/hypridle.conf      # Hyprland: 300s lock, 600s dpms, 900s suspend is common
systemd-inhibit --list                                  # who blocks sleep; Paseo holds no inhibitor itself
loginctl show-session <sid> -p LockedHint -p IdleHint
```

Agent CLIs may hold `idle:block` inhibitors (omp does; "omp agent session"), which block `systemctl suspend` — that is why suspends sometimes *don't* happen, and why OpenCode/Aider/Claude runs (no inhibitor) do get frozen.

## 4. Fixes

- **Stop the sleep** (the actual fix for agents stalling): raise/remove the suspend listener, or gate it. hypridle has no reload action — restart it, e.g. `hyprctl dispatch 'hl.dsp.exec_cmd("exec hypridle -v > /tmp/hypridle.log 2>&1")'` (Lua dispatcher era; older Hyprland uses `hyprctl dispatch exec ...`), then verify by grepping `Registered timeout rule for` in the log.
- **Make the daemon a service** so it survives logout/crashes:

```ini
# ~/.config/systemd/user/paseo.service
[Unit]
Description=Paseo daemon (supervisor + worker)
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=0

[Service]
Type=simple
ExecStart=%h/.npm-global/bin/paseo daemon start --foreground
Environment=PATH=<full PATH containing node, bun, provider CLIs>
Restart=always
RestartSec=3
TimeoutStopSec=30
KillMode=mixed

[Install]
WantedBy=default.target
```

```bash
loginctl enable-linger $USER
systemctl --user daemon-reload && systemctl --user enable --now paseo.service
```

Cut over by stopping the old instance first (`paseo daemon stop`), or the port/pid file conflicts. Verify with `systemctl --user show paseo.service -p MainPID -p NRestarts`, the cgroup tree, `paseo daemon status --json`, `paseo ls -g --json`, and a forced crash (`systemctl --user kill -s SIGKILL paseo.service` → new MainPID).

**Gotcha to disclose:** with `Restart=always`, `paseo daemon stop` comes back in ~3 s. Use `systemctl --user stop paseo.service` to stop it for real.
