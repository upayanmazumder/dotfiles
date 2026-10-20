#!/usr/bin/env bash
# Show one local battery status without external services.
for battery in /sys/class/power_supply/BAT*; do
  [[ -r "$battery/capacity" && -r "$battery/status" ]] || continue
  read -r percent <"$battery/capacity"
  read -r state <"$battery/status"
  if [[ "$state" == Charging ]]; then
    printf 'Charging %s%%\n' "$percent"
  else
    printf 'Battery %s%%\n' "$percent"
  fi
  break
done