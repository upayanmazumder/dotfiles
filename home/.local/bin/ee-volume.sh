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
# HARD CAP AT 150%
# -----------------
# This is a REAL hardware/bluez sink, not the cosmetic easyeffects_sink
# -- volume here is genuine gain applied to the physical output. Above
# 100% (0dB, unity gain) this is software boost applied AFTER the whole
# EasyEffects chain -- EE's own limiter sits upstream of this final sink
# gain. That used to hard-clip on loud/bass-heavy material. Since
# 2026-09-23 the Speakers-Balanced preset carries ~10 dB of headroom for
# exactly this (EQ output-gain -12, limiter threshold -11), so a 150%
# boost lands at about -0.43 dBFS instead of +9.57 dBFS. That headroom
# and this cap are coupled: raising the cap above 150% requires lowering
# the limiter threshold by the same amount in the preset, or clipping
# comes straight back. 150% is also the ceiling GNOME/KDE default to for
# weak laptop speakers. Remaining breakup at 150% on bass-heavy tracks is
# driver excursion, not clipping -- see docs/machine.md. The raise-volume
# key repeats while held, so relative "+2%" with no ceiling at all would
# climb unbounded -- always clamp to an absolute value in [0, 150].
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

clamp() {
  local v="$1"
  (( v < 0 )) && v=0
  (( v > 150 )) && v=150
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
