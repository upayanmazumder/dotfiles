#!/usr/bin/env bash
# Watches ~/GoogleDrive for local edits and reacts near-instantly by
# triggering rclone-sync-all.service, instead of waiting for the poll timer.
# Debounces bursts of events (e.g. saving many files) into a single sync run.
set -euo pipefail

BASE="$HOME/GoogleDrive"
DEBOUNCE_SECS=8
EVENTS="modify,create,delete,move,close_write"

mkdir -p "$BASE"

while true; do
  # Block until something changes locally.
  inotifywait -r -e "$EVENTS" -q "$BASE" >/dev/null 2>&1 || { sleep 2; continue; }

  # Drain further events until things go quiet for DEBOUNCE_SECS,
  # so one save-storm triggers one sync instead of dozens.
  while inotifywait -r -e "$EVENTS" -t "$DEBOUNCE_SECS" -q "$BASE" >/dev/null 2>&1; do
    :
  done

  systemctl --user start rclone-sync-all.service
done
