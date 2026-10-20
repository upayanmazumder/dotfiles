#!/usr/bin/env bash
# Auto-discover every top-level folder in Google Drive and keep a local
# two-way (bisync) copy of each under ~/GoogleDrive/<folder>.
# New folders that appear in Drive are picked up automatically on the next run.
set -euo pipefail

BASE="$HOME/GoogleDrive"
STATE_DIR="$HOME/.local/state"
LOGFILE="$STATE_DIR/rclone-sync-all.log"
LOCKFILE="$STATE_DIR/rclone-sync-all.lock"
AUTH_FAIL_STATE="$STATE_DIR/rclone-auth-fail.state"
AUTH_REMIND_SECS=900  # retry the reauth flow every 15min while auth stays broken
REAUTH_TIMEOUT_SECS=300  # give the user 5min to complete the browser flow per attempt

mkdir -p "$BASE" "$STATE_DIR"

exec 9>"$LOCKFILE"
if ! flock -n 9; then
  echo "$(date -Is) sync-all already running elsewhere, skipping this trigger" >> "$LOGFILE"
  exit 0
fi

sanitize() {
  # turn a Drive folder name into a safe filename fragment for the marker file
  printf '%s' "$1" | tr '/ ' '__'
}

is_auth_error() {
  grep -qiE 'invalid.*(credential|grant)|401|authError|couldn.t find root directory ID|oauth2: cannot fetch token' <<<"$1"
}

declare -A FOLDER_COUNTS
TOTAL_COUNT=0

record_transfers() {
  local name="$1" slice="$2" n
  n=$(grep -cE ': (Copied \(new\)|Copied \(replaced existing\)|Deleted|Moved)' <<<"$slice" || true)
  if (( n > 0 )); then
    FOLDER_COUNTS["$name"]=$(( ${FOLDER_COUNTS["$name"]:-0} + n ))
    TOTAL_COUNT=$(( TOTAL_COUNT + n ))
  fi
}

notify_sync_activity() {
  (( TOTAL_COUNT == 0 )) && return
  local names plural="s"
  names=$(printf '%s, ' "${!FOLDER_COUNTS[@]}")
  names=${names%, }
  (( TOTAL_COUNT == 1 )) && plural=""
  /usr/bin/notify-send -u normal -a "Google Drive Sync" \
    "Synced $TOTAL_COUNT file$plural to Google Drive" \
    "$names" \
    2>>"$LOGFILE" || true
}

attempt_reauth() {
  local now last=0
  now=$(date +%s)
  [[ -f "$AUTH_FAIL_STATE" ]] && last=$(cat "$AUTH_FAIL_STATE")

  # A previous attempt is still running (user may be mid-flow in the browser) -- leave it alone.
  if systemctl --user is-active --quiet rclone-reconnect.service 2>/dev/null; then
    return
  fi

  if (( now - last >= AUTH_REMIND_SECS )); then
    /usr/bin/notify-send -u critical -a "Google Drive Sync" \
      "Google Drive sync is broken" \
      "rclone auth to gdrive: expired -- opening browser to reauthorize (retrying every 15min until authed)" \
      2>>"$LOGFILE" || true
    /usr/bin/systemd-run --user --unit=rclone-reconnect --collect \
      --description="rclone gdrive: reauth" \
      /usr/bin/timeout "$REAUTH_TIMEOUT_SECS" /usr/bin/rclone config reconnect gdrive: --auto-confirm \
      >>"$LOGFILE" 2>&1 || true
    echo "$now" > "$AUTH_FAIL_STATE"
  fi
}

clear_auth_failure() {
  rm -f "$AUTH_FAIL_STATE"
}

LIST_ERR_FILE=$(mktemp)
LIST_STATUS=0
LIST_JSON=$(/usr/bin/rclone lsjson gdrive: --dirs-only 2>"$LIST_ERR_FILE") || LIST_STATUS=$?
LIST_ERR=$(cat "$LIST_ERR_FILE")
rm -f "$LIST_ERR_FILE"
printf '%s\n' "$LIST_ERR" >> "$LOGFILE"

if [[ $LIST_STATUS -ne 0 ]]; then
  is_auth_error "$LIST_ERR" && attempt_reauth
  echo "$(date -Is) no top-level folders found (or listing failed)" >> "$LOGFILE"
  exit 0
fi

mapfile -t FOLDERS < <(jq -r '.[].Name' <<<"$LIST_JSON")

if [[ ${#FOLDERS[@]} -eq 0 ]]; then
  echo "$(date -Is) no top-level folders found (or listing failed)" >> "$LOGFILE"
  exit 0
fi

clear_auth_failure

FLAGS=(
  --create-empty-src-dirs
  --compare size,modtime,checksum
  --resilient
  --recover
  --max-lock 5m
  --log-file "$LOGFILE"
  --log-level INFO
)

for name in "${FOLDERS[@]}"; do
  [[ -z "$name" ]] && continue
  local_dir="$BASE/$name"
  marker="$STATE_DIR/rclone-bisync-$(sanitize "$name").initialized"
  mkdir -p "$local_dir"
  pre_lines=$(wc -l < "$LOGFILE" 2>/dev/null || echo 0)
  if [[ ! -f "$marker" ]]; then
    echo "$(date -Is) [$name] new folder detected: performing initial --resync baseline" >> "$LOGFILE"
    run_ok=1
    /usr/bin/rclone bisync "gdrive:$name" "$local_dir" --resync "${FLAGS[@]}" || run_ok=0
    slice=$(tail -n +"$((pre_lines + 1))" "$LOGFILE")
    record_transfers "$name" "$slice"
    if [[ $run_ok -eq 1 ]]; then
      touch "$marker"
    else
      echo "$(date -Is) [$name] initial resync FAILED, will retry next run" >> "$LOGFILE"
      is_auth_error "$slice" && attempt_reauth
    fi
  else
    run_ok=1
    /usr/bin/rclone bisync "gdrive:$name" "$local_dir" "${FLAGS[@]}" || run_ok=0
    slice=$(tail -n +"$((pre_lines + 1))" "$LOGFILE")
    record_transfers "$name" "$slice"
    if [[ $run_ok -eq 0 ]]; then
      echo "$(date -Is) [$name] bisync run failed; clearing marker so next run rebuilds via --resync" >> "$LOGFILE"
      rm -f "$marker"
      is_auth_error "$slice" && attempt_reauth
    fi
  fi
done

notify_sync_activity
