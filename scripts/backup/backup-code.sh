#!/usr/bin/env bash
# backup-code.sh -- snapshot ~/dev, ~/Code, and ~/Sync to a destination using rsync
# hardlink snapshots (cheap, dependency-free "Time Machine" style backups:
# unchanged files are hardlinked from the previous snapshot, so each
# snapshot dir looks complete but only changed bytes cost extra space).
#
# Usage:
#   backup-code.sh <destination-root>
#   backup-code.sh /mnt/backup-drive
#
# Creates <destination-root>/<YYYY-MM-DD_HHMMSS>/ and updates
# <destination-root>/latest -> that snapshot.
set -euo pipefail

dest_root="${1:?usage: backup-code.sh <destination-root>}"
timestamp="$(date +%Y-%m-%d_%H%M%S)"
snapshot="$dest_root/$timestamp"
latest_link="$dest_root/latest"

sources=("$HOME/dev" "$HOME/Code" "$HOME/Sync")

echo "==> backing up ${sources[*]} -> $snapshot"

rsync_link_dest=()
if [ -e "$latest_link" ]; then
  rsync_link_dest=(--link-dest="$latest_link")
fi

for src in "${sources[@]}"; do
  [ -d "$src" ] || { echo "skip (missing): $src"; continue; }
  name="$(basename "$src")"
  rsync -a --delete \
    --exclude 'node_modules/' --exclude '.venv/' --exclude 'target/' \
    --exclude '__pycache__/' --exclude '.next/' --exclude 'dist/' \
    "${rsync_link_dest[@]}" \
    "$src/" "$snapshot/$name/"
done

rm -f "$latest_link"
ln -s "$snapshot" "$latest_link"

echo "==> done: $snapshot (latest -> $snapshot)"
