#!/usr/bin/env bash
# mirror-refresh.sh -- refresh the pacman mirrorlist with reflector and run
# a full system update. Idempotent guard: refuses to re-run the (slow)
# mirror ranking within MIN_INTERVAL_HOURS of the last run, tracked via a
# stamp file -- pass --force to override.
set -euo pipefail

STAMP_FILE="$HOME/.cache/scripts-mirror-refresh.stamp"
MIN_INTERVAL_HOURS="${MIN_INTERVAL_HOURS:-24}"

force=0
[ "${1:-}" = "--force" ] && force=1

should_refresh_mirrors() {
  [ "$force" -eq 1 ] && return 0
  [ ! -f "$STAMP_FILE" ] && return 0
  last="$(cat "$STAMP_FILE")"
  now="$(date +%s)"
  elapsed_hours=$(( (now - last) / 3600 ))
  [ "$elapsed_hours" -ge "$MIN_INTERVAL_HOURS" ]
}

if command -v reflector >/dev/null 2>&1 && should_refresh_mirrors; then
  echo "==> ranking mirrors with reflector"
  sudo reflector --country India --latest 10 --sort rate --save /etc/pacman.d/mirrorlist
  mkdir -p "$(dirname "$STAMP_FILE")"
  date +%s > "$STAMP_FILE"
else
  echo "==> skipping mirror refresh (reflector missing or ran within ${MIN_INTERVAL_HOURS}h -- use --force to override)"
fi

echo "==> full system update"
sudo pacman -Syu --noconfirm

if command -v paru >/dev/null 2>&1; then
  echo "==> AUR update"
  paru -Sua --noconfirm
fi
