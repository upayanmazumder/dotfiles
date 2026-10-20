#!/usr/bin/env bash
# easyeffects-bt-relink.sh
#
# Keeps EasyEffects' real hardware output converged on the *intended*
# route: the manual pin if one is set (audio-output-switch.sh, the
# quickshell bar button), else the BT-always-wins policy from
# 51-bluetooth-audio-priority.conf. See lib/audio-output-routing.sh for
# why the real link cannot be left to EasyEffects itself.
#
# HOW IT WORKS (2026-10-02 rewrite)
# ---------------------------------
#   * converge(): if EE's chain is up and its output is linked to the
#     wrong real sink, re-point the link (pw-link, no restart). If the
#     chain is up but unlinked, link it. If the chain is down there is
#     nothing to move yet -- the next stream start rebuilds it and the
#     loop picks the new link up.
#   * The loop idles at one check per SLOW_TICK (5s) and switches to
#     FAST_TICK (0.2s) for a few seconds after any hint that something
#     changed: a pulse event from `pactl subscribe` (stream started,
#     stream corked/uncorked, device added/removed, default changed) or a
#     wake file touched by the manual switch. That fast window is what
#     makes a switch made while nothing is playing land on the *first*
#     stream that starts afterwards within ~0.2s, instead of 15-25s later
#     (old sweep + recheck) or never.
#   * EasyEffects is restarted only as a last resort: EE destroys its DSP
#     chain when its output device vanishes (headset walks out of range)
#     and does not rebuild it -- "streams playing into a void". That is
#     detected as: chain gone for WEDGE_GRACE while audio is *actually*
#     playing (uncorked; a paused Spotify keeps a stream listed forever
#     and must not count), and the restart is rate-limited to at most one
#     per RESTART_MIN_INTERVAL.
#
# WHY NO MORE D-BUS WATCHING / DEBOUNCE / GENERATION COUNTERS:
# The previous version restarted EasyEffects on every BlueZ Connected
# change, debounced, and used a 15s sweep plus an 8s recheck to decide
# whether it had "worked". Reproduced live on 2026-10-02: with a manual
# override active and a listed-but-paused stream (Spotify, Corked: yes),
# converge could not succeed -- the chain was down while EE's slow chain
# rebuild ran, or EE had re-linked to its own stored device -- so the next
# sweep called it broken again and restarted EE again, every ~22s
# indefinitely (30+ restarts in 10 minutes in `journalctl --user -u
# easyeffects-bt-relink.service`, each one a full DSP gap). A BT connect/
# disconnect does not need a restart at all: EE's pick is its own stored
# outputDevice and never changes on its own, so the only thing that has to
# happen is moving the link -- which is exactly what converge() does, with
# no gap and no flicker to feed a loop. Restarts remain only for the
# genuine "EE is gone while audio plays" wedge above.
#
# GOTCHAS ALREADY BITTEN (keep these in mind when editing):
#  1. pkill pattern MUST match the real autostart invocation
#     (--hide-window --service-mode), not an assumed one.
#  2. A systemd --user service has no WAYLAND_DISPLAY/DISPLAY by default;
#     pull them from `systemctl --user show-environment` at launch time.
#  3. EasyEffects' DSP chain flickers (tears down and rebuilds once more)
#     for up to ~20s after a fresh launch. Never assert a routing fix
#     inside that window: the old version did, and the assert-then-retry
#     logic turned the flicker into the restart loop described above.
#  4. The service unit must keep KillMode=process, otherwise stopping the
#     daemon kills the detached EasyEffects process too.

set -u
# shellcheck source=lib/audio-output-routing.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/audio-output-routing.sh"

SLOW_TICK=5         # seconds between checks when nothing is happening
FAST_TICK=0.2       # ... and inside a fast window
FAST_WINDOW=3       # seconds a wake/restart keeps the loop in fast mode
FAST_CAP=15         # never stay fast for longer than this per episode
WEDGE_GRACE=15      # chain gone + audio playing for this long -> restart
RESTART_MIN_INTERVAL=180
MIC_CHECK_INTERVAL=15

RESTART_LOCK_FILE="$ROUTING_RUNTIME_DIR/restart.lock"

log() { printf '%s %s\n' "$(date '+%F %T')" "$*"; }

# The unit's KillMode=process (deliberate, see the unit file) SIGTERMs only
# this PID, so children -- the pactl subscribe wake reader and the sleeps --
# would be left behind as orphans on every service restart (observed: a
# stale `pactl subscribe` after the first restart). This script is its own
# process-group and session leader (verified: PGID and SID == main PID), so
# signalling group 0 cleans up exactly our own helpers and nothing else --
# in particular not EasyEffects, which restart_easyeffects() deliberately
# launches with setsid into its own group.
cleanup() { trap - TERM INT; kill 0 2>/dev/null; exit 0; }
trap cleanup TERM INT

restart_easyeffects() {
  # Serialize restarts: the converge loop is single-threaded, but a
  # restart takes ~3s and the loop keeps ticking, so make it explicit.
  # The `9>"$LOCK_FILE"` redirection is SCOPED TO THE FUNCTION CALL, so
  # fd 9 (and its flock) is released when the function returns. Using
  # `exec 9>` here instead would leave the fd open with the lock held
  # forever, making every later restart skip ("already in progress").
  if ! flock -n 9; then
    log "restart already in progress, skipping"
    return 1
  fi

  pkill -f 'easyeffects --hide-window --service-mode' 2>/dev/null
  pkill -f 'easyeffects --gapplication-service' 2>/dev/null
  sleep 0.5

  local attempt wayland_display display
  for attempt in 1 2; do
    wayland_display=$(systemctl --user show-environment 2>/dev/null | sed -n 's/^WAYLAND_DISPLAY=//p')
    display=$(systemctl --user show-environment 2>/dev/null | sed -n 's/^DISPLAY=//p')
    WAYLAND_DISPLAY="${wayland_display:-wayland-1}" DISPLAY="${display:-:0}" \
      setsid easyeffects --hide-window --service-mode >/dev/null 2>&1 9>&- &
    disown
    sleep 2.5
    if pgrep -f 'easyeffects --hide-window --service-mode' >/dev/null 2>&1; then
      log "restarted EasyEffects (attempt $attempt); its chain takes up to ~20s to settle"
      return 0
    fi
    log "WARNING: EasyEffects relaunch attempt $attempt did not stay up, retrying"
    sleep 1
  done
  log "ERROR: EasyEffects relaunch failed after 2 attempts"
  return 1
} 9>"$RESTART_LOCK_FILE"

# The built-in laptop mic is the intended default input. Bluetooth
# headset mics must NOT take it over: in A2DP (music) mode they are pure
# silence, and in HSP/HFP mode they are mono call-quality. If the default
# source ever becomes a bluez_input (WirePlumber tends to re-select the
# just-connected BT device), point it back at the laptop mic.
LAPTOP_MIC="alsa_input.pci-0000_04_00.6.HiFi__Mic1__source"
ensure_laptop_mic() {
  local cur
  cur=$(timeout 5 pactl get-default-source 2>/dev/null)
  if [[ "$cur" == bluez_input* ]]; then
    timeout 5 pactl set-default-source "$LAPTOP_MIC" 2>/dev/null
    log "input fix: default source was '$cur' (BT headset mic), switched to laptop mic"
  fi
}

# Make the real graph match the intent, once. Returns 0 when it already
# does (or was just made to), 1 when it could not be satisfied right now
# (chain down, or the target sink is not there yet) -- the caller uses
# that to decide whether to keep checking fast.
converge() {
  local desired cur count state now
  desired=$(desired_sink_name)
  read -r cur count < <(ee_output_state)
  write_current_route

  # Satisfied only when there are exactly two links (one per channel) and
  # they go to the intended sink. A first-match comparison is not enough:
  # a duplicate link -- an extra copy of the processed signal, see the
  # "do not hand-create extra links" note in docs/machine.md -- leaves the
  # first link looking correct, which is how one survived this daemon for
  # minutes on 2026-10-02.
  if [[ "$cur" == "$desired" ]] && (( count == 2 )); then
    wedge_since=0
    return 0
  fi

  if ee_chain_present; then
    # Chain up, but connected nowhere / to the wrong device / more than
    # once (the wrong-device case is the normal state right after EE
    # rebuilds its chain: it links to its own stored output device, not to
    # the intended route).
    wedge_since=0
    state="${cur:-unlinked}"
    (( count > 2 )) && state="${cur:-unlinked} (${count} links)"
    log "chain output is ${state}, intended $desired - re-pointing"
    relink_ee_output "$desired" && { log "re-pointed to $desired"; return 0; }
    log "WARNING: could not re-point the chain output to $desired"
    return 1
  fi

  # Chain is gone entirely: normal while EE is idle, a wedge only if audio
  # is actually playing and EE does not come back by itself.
  if ! streams_playing; then
    wedge_since=0
    return 1
  fi

  now=$(date +%s)
  (( wedge_since == 0 )) && wedge_since=$now
  (( now - wedge_since < WEDGE_GRACE )) && return 1

  if (( now - last_restart < RESTART_MIN_INTERVAL )); then
    log "no EE output chain for $((now - wedge_since))s of playback, but EasyEffects was restarted $((now - last_restart))s ago - leaving it alone"
    wedge_since=$now
    return 1
  fi

  log "EasyEffects output chain gone for ${WEDGE_GRACE}s while audio is playing - restarting EasyEffects"
  last_restart=$now
  wedge_since=0
  restart_easyeffects
}

# Wake the loop on pulse events: a stream starting (the moment a switch
# made while idle has to land), a stream corking/uncorking, a device
# appearing/disappearing (Bluetooth connect), or the default changing.
# Only wakes on events that can affect routing -- not on, say, volume or
# client changes. Reconnects if pipewire-pulse restarts; the SLOW_TICK
# path keeps working without it either way.
while true; do
  pactl subscribe 2>/dev/null | while IFS= read -r line; do
    case "$line" in
      *sink*|*source*|*server*|*card*) : > "$WAKE_FILE" ;;
    esac
  done
  sleep 1
done &
disown

# Run converge() in a loop, with a cheap wake channel so a change is acted
# on in ~FAST_TICK instead of at the next SLOW_TICK.
wedge_since=0
last_restart=0
unsat_since=0
fast_until=0
next_mic_check=0
wake_converger   # converge immediately on startup

while true; do
  if converge; then
    unsat_since=0
  elif streams_playing && (( SECONDS - unsat_since < FAST_CAP )); then
    # Audio is playing but the intent is not satisfied yet (the chain is
    # still being built, or EE keeps re-linking): keep watching closely,
    # but not forever -- FAST_CAP bounds the cost if it never converges.
    (( unsat_since == 0 )) && unsat_since=$SECONDS
    fast_until=$((SECONDS + FAST_WINDOW))
  fi

  if [[ -f "$WAKE_FILE" ]]; then
    rm -f "$WAKE_FILE"
    unsat_since=0
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
