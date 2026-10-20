#!/usr/bin/env bash
# Exercise status against fake /proc cmdlines; never starts a real hotspot.
set -euo pipefail

script="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/hotspot.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/proc/101" "$tmp/proc/102" "$tmp/proc/103" "$tmp/proc/104"

status() { HOME="$tmp/home" HOTSPOT_PROC_ROOT="$tmp/proc" bash "$script" status; }
inactive() { if status; then echo 'expected inactive hotspot' >&2; exit 1; fi; }
active() { if ! status; then echo 'expected active hotspot' >&2; exit 1; fi; }

# A parent shell containing the old pgrep pattern is not a daemon.
printf '/usr/bin/bash\0-lc\0pgrep -f "create_ap --daemon wlan0 wlan0 Fake"\0' > "$tmp/proc/101/cmdline"
inactive

# A foreground create_ap or a daemon for another interface is not ours.
printf '/usr/bin/bash\0/usr/bin/create_ap\0wlan0\0wlan0\0Fake\0example-only\0' > "$tmp/proc/102/cmdline"
printf '/usr/bin/bash\0/usr/bin/create_ap\0--daemon\0wlan1\0wlan1\0Fake\0example-only\0' > "$tmp/proc/103/cmdline"
inactive

# Only an actual daemon argv with our pair of interface arguments counts.
printf '/usr/bin/bash\0/usr/bin/create_ap\0--daemon\0-c\00011\0wlan0\0wlan0\0Fake\0example-only\0' > "$tmp/proc/104/cmdline"
active
rm "$tmp/proc/104/cmdline"
inactive
