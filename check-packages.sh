#!/usr/bin/env bash
# Report explicitly-installed packages not yet tracked in packages/*.txt, so
# newly installed software gets added deliberately instead of silently
# drifting. Does not modify anything -- review output, then edit the .txt
# files by hand and commit.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

listed() { grep -hvE '^\s*#|^\s*$' "$SCRIPT_DIR/packages/pacman.txt" "$SCRIPT_DIR/packages/hardware.txt" "$SCRIPT_DIR/packages/aur.txt" | sort -u; }

echo "== repo packages installed but not in packages/pacman.txt or hardware.txt =="
comm -23 <(pacman -Qqe | sort -u) <(listed)

echo
echo "== AUR packages installed but not in packages/aur.txt =="
comm -23 <(pacman -Qqm | sort -u) <(listed)
