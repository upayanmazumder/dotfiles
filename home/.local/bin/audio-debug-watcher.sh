#!/usr/bin/env bash
# audio-debug-watcher.sh
#
# Persistent watcher that logs everything that could explain "audio
# pauses / breaks sometimes". Four parallel capture sources, all writing
# timestamped, tagged lines to one log file:
#
#   [graph]  pw-mon: PipeWire graph events -- nodes added/removed/changed
#            (easyeffects_sink recreation, bluez sink appearing/vanish),
#            stream state changes (idle/running/error/corked), Volume and
#            Mute param changes on any node/stream, link create/remove.
#   [bt]     dbus-monitor on BlueZ: every Connected-property flip of any
#            Bluetooth device (the RF flapping that triggers restarts).
#   [svc]    journalctl -f: pipewire / pipewire-pulse / wireplumber /
#            easyeffects-bt-relink.service log lines (errors, xruns,
#            "Could not find a node", coredumps, watcher activity).
#   [ee]     poll every 2s: EasyEffects process lifecycle (start, stop,
#            pid change = restart), since every restart kills active
#            streams and that is a prime suspect for audible pauses.
#
# Logs: $XDG_STATE_HOME/audio-debug/audio-debug.log (rotated at 20MB,
# keeps 3 generations: .log, .log.1, .log.2, .log.3). The systemd unit
# audio-debug-watcher.service keeps this alive across reboots; the same
# lines also reach the journal under that unit name.
#
# Grep hints:
#   "paused|Corked|state.*(idle|error)"  -- stream pauses
#   "Connected property change"          -- bluetooth flaps
#   "PID changed"                        -- easyeffects restarts
#   "Volume.*0\."                        -- streams dropping to ~0 volume

set -u

LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/audio-debug"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/audio-debug.log"
ROTATE_BYTES=20971520   # 20 MB
KEEP=3

ts() { date '+%F %T.%3N'; }

write_log() {
  local tag="$1"; shift
  {
    flock -x 9
    printf '%s [%s] %s\n' "$(ts)" "$tag" "$*" >> "$LOG_FILE"
    if (( $(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0) >= ROTATE_BYTES )); then
      for i in $(seq "$KEEP" -1 1); do
        local p=$((i-1))
        [[ -f "$LOG_FILE.$p" ]] && mv -f "$LOG_FILE.$p" "$LOG_FILE.$i"
      done
      mv -f "$LOG_FILE" "$LOG_FILE.1"
      : > "$LOG_FILE"
    fi
  } 9>>"$LOG_FILE"
}

write_log SYSTEM "audio-debug-watcher started (pid $$), logging to $LOG_FILE"

# --- 1. PipeWire graph events ---------------------------------------------
pw-mon -C never -p 2>&1 | while IFS= read -r line; do
  [[ -n "$line" ]] && write_log graph "$line"
done &
GRAPH_PID=$!

# --- 2. Bluetooth Connected flaps -------------------------------------------
stdbuf -oL -eL dbus-monitor --system "type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',path_namespace='/org/bluez'" 2>/dev/null | while IFS= read -r line; do
  case "$line" in
    *'"Connected"'*)
      read -r val
      write_log bt "Connected property change: $val"
      ;;
  esac
done &
BT_PID=$!

# --- 3. Audio service journal lines -------------------------------------------
journalctl --user -n 0 -f -u pipewire -u pipewire-pulse -u wireplumber -u easyeffects-bt-relink.service 2>&1 | while IFS= read -r line; do
  [[ -n "$line" ]] && write_log svc "$line"
done &
JRNL_PID=$!

# --- 4. EasyEffects process lifecycle -----------------------------------------
last_ee=""
while true; do
  cur=$(pgrep -f 'easyeffects --hide-window --service-mode' 2>/dev/null | head -1)
  if [[ "$cur" != "$last_ee" ]]; then
    if [[ -n "$last_ee" && -z "$cur" ]]; then
      write_log ee "EasyEffects STOPPED (was pid $last_ee)"
    elif [[ -z "$last_ee" && -n "$cur" ]]; then
      write_log ee "EasyEffects STARTED (pid $cur)"
    elif [[ -n "$last_ee" && -n "$cur" ]]; then
      write_log ee "EasyEffects PID changed: $last_ee -> $cur (likely restarted)"
    fi
    last_ee="$cur"
  fi
  sleep 2
done &
EE_PID=$!

write_log SYSTEM "all watchers running (graph=$GRAPH_PID bt=$BT_PID journal=$JRNL_PID ee=$EE_PID)"

trap 'write_log SYSTEM "shutting down"; kill "$GRAPH_PID" "$BT_PID" "$JRNL_PID" "$EE_PID" 2>/dev/null' TERM INT
wait
