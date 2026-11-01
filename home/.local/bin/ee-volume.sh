#!/usr/bin/env bash
# ee-volume.sh: control the REAL system output volume.
#
# WHY THIS EXISTS
# ----------------
# easyeffects_sink's own PipeWire volume is COSMETIC. EasyEffects reads
# audio for its DSP chain from easyeffects_sink's *monitor* port, and
# PipeWire monitor ports are pre-fader by convention (so metering/
# recording apps see an unprocessed signal) -- confirmed by measuring
# actual output amplitude at 5% vs 90% easyeffects_sink volume: no
# audible difference reaches the hardware. So @DEFAULT_AUDIO_SINK@
# (which resolves to easyeffects_sink, since it's pinned as the system
# default so all app audio routes through the effects chain) is the
# wrong target for volume/mute keys.
#
# This instead finds whichever REAL hardware sink is currently receiving
# EasyEffects' processed output (any connected Bluetooth sink, else the
# built-in speaker -- matching the priority in
# 51-bluetooth-audio-priority.conf) and adjusts that sink directly.
#
# CAP: 153% ON THE SPEAKER, 100% ELSEWHERE
# ----------------------------------------
# 153% is PulseAudio's UI maximum and the limit pavucontrol offers. It is
# +11.08 dB of real gain (PipeWire volume is cubic), applied to the real
# sink AFTER the EasyEffects limiter. Only the Speakers-* presets reserve
# that headroom: their limiter has gain-boost off and a -12 dBFS ceiling,
# so a full-scale peak lands at about -0.9 dBFS at 153%. The Bluetooth and
# DAC presets keep a 0 dBFS ceiling, so any other sink stays at 100%.
# If you raise MAX_SPEAKER_PCT or lower the ceiling margin, change the
# limiter threshold in both Speakers-* presets by the same amount.
#
# SINGLE SOURCE OF TRUTH
# -----------------------
# easyeffects_sink's own volume is what the OSD/sliders display, but the
# REAL sink is what you actually hear. If each is nudged independently
# by the same relative delta, they drift apart the moment they ever
# start at different values (which happens easily -- Bluetooth
# reconnects, manual pactl calls, etc.) -- e.g. one ends up at 132%
# displayed while the real output is only at 82%, so "max" looks loud
# but sounds quiet. To make this impossible, every operation here
# computes ONE target percentage from the real sink's current value and
# writes that SAME percentage to both sinks, so the displayed value and
# the real gain can never diverge again.

set -u

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/audio-output-routing.sh"

target_sink() {
  local linked
  linked=$(ee_output_target)
  if [[ -n "$linked" ]]; then
    echo "$linked"
  else
    desired_sink_name
  fi
}

current_pct() {
  pactl get-sink-volume "$1" 2>/dev/null | grep -oP '\d+(?=%)' | head -1
}

MAX_SPEAKER_PCT=153

max_pct() {
  if [[ "$sink" == "$SPEAKER_SINK" ]]; then echo "$MAX_SPEAKER_PCT"; else echo 100; fi
}

clamp() {
  local v="$1" max
  max="$(max_pct)"
  (( v < 0 )) && v=0
  (( v > max )) && v=$max
  echo "$v"
}

apply_both() {
  local pct="$1"
  pactl set-sink-volume "$sink" "${pct}%"
  pactl set-sink-volume easyeffects_sink "${pct}%" 2>/dev/null
}

action="${1:-}"
arg="${2:-}"
sink="$(target_sink)"

case "$action" in
  up)
    step="${arg%\%}"; step="${step:-2}"
    cur="$(current_pct "$sink")"; cur="${cur:-0}"
    apply_both "$(clamp $((cur + step)))"
    ;;
  down)
    step="${arg%\%}"; step="${step:-2}"
    cur="$(current_pct "$sink")"; cur="${cur:-0}"
    apply_both "$(clamp $((cur - step)))"
    ;;
  set)
    pct="${arg%\%}"; pct="${pct:-0}"
    apply_both "$(clamp "$pct")"
    ;;
  mute-toggle)
    cur_mute="$(pactl get-sink-mute "$sink" 2>/dev/null | grep -oP '(?<=Mute: )(yes|no)')"
    if [[ "$cur_mute" == "yes" ]]; then new_mute=0; else new_mute=1; fi
    pactl set-sink-mute "$sink" "$new_mute"
    pactl set-sink-mute easyeffects_sink "$new_mute" 2>/dev/null
    ;;
  mute-set)
    pactl set-sink-mute "$sink" "$arg"
    pactl set-sink-mute easyeffects_sink "$arg" 2>/dev/null
    ;;
  *)
    echo "usage: ee-volume.sh {up|down [pct]|set <pct>|mute-toggle|mute-set <0|1>}" >&2
    exit 1
    ;;
esac
