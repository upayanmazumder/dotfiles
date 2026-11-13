#!/usr/bin/env bash
# Maintain the selected hardware route without restarting a live Easy Effects process.
# Easy Effects tracks the hardware default. Relinking repairs stale output links.
# Native autoload selects device presets. Apply an override only when its value changes.
# A manual preset change must persist while the selected route stays unchanged.
set -u
# shellcheck source=lib/audio-output-routing.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/audio-output-routing.sh"

SLOW_TICK=5
FAST_TICK=0.2
FAST_WINDOW=3
MIC_CHECK_INTERVAL=15
RECOVERY_GRACE=30
RECOVERY_INTERVAL=180
last_preset_desired=""
missing_since=0
last_launch=0

log() { printf '%s %s\n' "$(date '+%F %T')" "$*"; }

# The service owns all helper processes. It never owns Easy Effects.
cleanup() {
  trap - TERM INT
  kill "$subscriber_pid" 2>/dev/null || true
  wait "$subscriber_pid" 2>/dev/null || true
  exit 0
}

recover_missing_process() {
  local now
  if pgrep -x easyeffects >/dev/null || ! streams_playing; then
    missing_since=0
    return
  fi
  now=$SECONDS
  (( missing_since == 0 )) && missing_since=$now
  (( now - missing_since >= RECOVERY_GRACE )) || return
  (( last_launch == 0 || now - last_launch >= RECOVERY_INTERVAL )) || return
  last_launch=$now
  # Launch outside this service's control group. Stopping the controller
  # must not stop audio. A live process is never killed for missing ports.
  systemd-run --user --collect --unit=easyeffects-recovery \
    --property=Type=exec /usr/bin/easyeffects --hide-window --service-mode &&
    log "started missing Easy Effects process"
}

LAPTOP_MIC="alsa_input.pci-0000_04_00.6.HiFi__Mic1__source"
ensure_laptop_mic() {
  local cur
  cur=$(timeout 5 pactl get-default-source 2>/dev/null)
  if [[ "$cur" == bluez_input* ]]; then
    timeout 5 pactl set-default-source "$LAPTOP_MIC" 2>/dev/null &&
      log "selected laptop microphone"
  fi
}

desired_output_preset() {
  case "$1" in
    bluez_output.B8_17_43_44_75_A3.*) echo Headphones-Reference ;;
    bluez_output.00_A4_1C_39_55_5B.*) echo Headphones-Flat ;;
    "$SPEAKER_SINK")
      if timeout 5 hyprctl getoption animations:enabled -j 2>/dev/null |
           jq -e '.bool == false' >/dev/null 2>&1; then
        echo Speakers-Game
      else
        echo Speakers-Night
      fi
      ;;
    *) echo Speakers-Night ;;
  esac
}

sync_output_preset() {
  local desired loaded
  desired=$(desired_output_preset "$1")
  [[ "$desired" == "$last_preset_desired" ]] && return 0
  pgrep -x easyeffects >/dev/null || return 0
  # Failed or empty queries are not evidence of a preset mismatch.
  loaded=$(QT_QPA_PLATFORM=offscreen timeout 5 easyeffects --last-loaded-preset output 2>/dev/null) || return 0
  [[ -n "$loaded" ]] || return 0
  if [[ "$loaded" != "$desired" ]]; then
    QT_QPA_PLATFORM=offscreen timeout 8 easyeffects --load-preset "$desired" >/dev/null 2>&1 || return 0
    log "loaded output preset $desired"
  fi
  last_preset_desired=$desired
}

converge() {
  local desired configured cur count
  desired=$(desired_sink_name)
  configured=$(timeout 5 pactl get-default-sink 2>/dev/null) || return 0
  if [[ -n "$desired" && "$configured" != "$desired" ]]; then
    timeout 5 pactl set-default-sink "$desired" 2>/dev/null || return 0
    log "selected output $desired"
  fi
  sync_output_preset "$desired"
  write_current_route
  read -r cur count < <(ee_output_state)
  if [[ "$cur" != "$desired" || "$count" != 2 ]] && ee_chain_present; then
    relink_ee_output "$desired" && log "repaired output links to $desired"
  fi
  recover_missing_process
}

# Keep the subscriber in this service's control group for complete cleanup.
(
  while true; do
    pactl subscribe 2>/dev/null | while IFS= read -r line; do
      case "$line" in
        *sink*|*source*|*server*|*card*) wake_converger ;;
      esac
    done
    sleep 1
  done
) &
subscriber_pid=$!
trap cleanup TERM INT

fast_until=0
next_mic_check=0
wake_converger
while true; do
  converge
  if [[ -f "$WAKE_FILE" ]]; then
    rm -f "$WAKE_FILE"
    fast_until=$((SECONDS + FAST_WINDOW))
  fi
  if (( SECONDS >= next_mic_check )); then
    ensure_laptop_mic
    next_mic_check=$((SECONDS + MIC_CHECK_INTERVAL))
  fi
  if (( SECONDS < fast_until )); then
    sleep "$FAST_TICK"
  else
    sleep "$SLOW_TICK"
  fi
done
