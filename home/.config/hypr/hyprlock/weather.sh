#!/usr/bin/env bash
# Weather widget for hyprlock. Caches last good reading so a dead/slow
# network on the lock screen never blocks or shows stale garbage for long.

cache="${XDG_CACHE_HOME:-$HOME/.cache}/hyprlock-weather"
mkdir -p "$(dirname "$cache")"

fresh=$(curl -s -m 2 "wttr.in?format=%C+%t" 2>/dev/null)

if [[ -n "$fresh" && "$fresh" != *"Unknown"* ]]; then
  echo "$fresh" >"$cache"
  echo "$fresh"
elif [[ -f "$cache" ]]; then
  cat "$cache"
fi
