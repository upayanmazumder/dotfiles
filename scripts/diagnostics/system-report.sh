#!/usr/bin/env bash
# system-report.sh -- bundle a dated diagnostic snapshot for bug reports:
# fastfetch summary, recent journal errors, disk usage, and pacman package
# list. Writes to ~/Sync/diagnostics/<timestamp>/ and prints the path.
set -euo pipefail

out_dir="$HOME/Sync/diagnostics/$(date +%Y-%m-%d_%H%M%S)"
mkdir -p "$out_dir"

if command -v fastfetch >/dev/null 2>&1; then
  fastfetch --logo none > "$out_dir/fastfetch.txt" 2>&1 || true
fi

journalctl -p err -b --no-pager > "$out_dir/journal-errors.txt" 2>&1 || true
df -h > "$out_dir/disk-usage.txt" 2>&1 || true
free -h > "$out_dir/memory.txt" 2>&1 || true
pacman -Qqe > "$out_dir/pacman-explicit.txt" 2>&1 || true
pacman -Qqm > "$out_dir/pacman-aur.txt" 2>&1 || true
uname -a > "$out_dir/kernel.txt" 2>&1 || true

echo "==> report written to $out_dir"
