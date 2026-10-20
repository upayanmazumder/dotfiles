#!/usr/bin/env bash
# audio-output-switch.sh: manually pin EasyEffects' real hardware output
# between the built-in speaker and a connected Bluetooth headset,
# overriding the automatic BT-always-wins policy
# (51-bluetooth-audio-priority.conf) -- e.g. "use speakers even though
# headphones are still paired/connected".
#
# Usage: audio-output-switch.sh {speaker|headphones|toggle|auto|status}
#
#   speaker    Pin output to the built-in speaker.
#   headphones Pin output to the connected Bluetooth headset (falls back
#              to the speaker, and switches to the headset on the next
#              converge, if nothing is connected right now).
#   toggle     Flip between the two based on the CURRENTLY INTENDED
#              route (override if set, else the BT-wins policy pick) --
#              not momentary PipeWire link state, which EasyEffects
#              itself churns on idle/resume (see lib comments).
#   auto       Clear the pin; go back to the BT-always-wins policy.
#   status     Print the currently intended route: speaker|headphones.
#
# Shares state/routing logic with easyeffects-bt-relink.sh (the daemon
# that keeps the real graph converged on this intent, including after
# EasyEffects rebuilds its chain on the next stream start) via
# lib/audio-output-routing.sh, so a manual switch here and the daemon
# never fight each other.
#
# A switch here is applied immediately when EasyEffects' chain is up
# (`relink_ee_output`); when it is not (nothing playing, EE suspended
# its chain) there is no link to move yet, so the intent is recorded and
# the daemon applies it the moment the chain reappears -- hence the
# `wake_converger` call, so that happens on the daemon's next fast tick
# rather than at its next safety tick.

set -u
# shellcheck source=lib/audio-output-routing.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/audio-output-routing.sh"

action="${1:-status}"

# Apply the intent now if possible, and prod the daemon either way.
apply_route() {
  relink_ee_output "$(desired_sink_name)"
  wake_converger
}

case "$action" in
  speaker)
    set_override speaker
    apply_route
    ;;
  headphones)
    set_override headphones
    apply_route
    ;;
  toggle)
    current="$(route_label_for_sink "$(desired_sink_name)")"
    if [[ "$current" == "headphones" ]]; then
      set_override speaker
    else
      set_override headphones
    fi
    apply_route
    ;;
  auto)
    clear_override
    apply_route
    ;;
  status)
    cat "$ROUTE_FILE" 2>/dev/null || echo "none"
    ;;
  *)
    echo "usage: audio-output-switch.sh {speaker|headphones|toggle|auto|status}" >&2
    exit 1
    ;;
esac
