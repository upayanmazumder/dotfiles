#!/usr/bin/env bash
# pacman-cleanup.sh -- remove orphaned packages and vacuum the pacman cache.
# Safe by default: lists what would be removed and asks for confirmation.
# Pass --yes to skip the prompt (e.g. for a scheduled timer).
set -euo pipefail

assume_yes=0
[ "${1:-}" = "--yes" ] && assume_yes=1

echo "==> orphaned packages (installed as a dependency, no longer required by anything)"
orphans="$(pacman -Qtdq || true)"
if [ -z "$orphans" ]; then
  echo "none"
else
  echo "$orphans"
  if [ "$assume_yes" -eq 1 ] || { read -rp "Remove these? [y/N] " reply; [[ "$reply" =~ ^[Yy]$ ]]; }; then
    sudo pacman -Rns --noconfirm $orphans
  fi
fi

echo "==> pacman cache (keeping 2 most recent versions of each package)"
if command -v paccache >/dev/null 2>&1; then
  sudo paccache -rk2
else
  echo "paccache not found (pacman-contrib not installed) -- skipping cache vacuum"
fi

echo "==> done"
