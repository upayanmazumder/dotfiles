#!/usr/bin/env bash
# rsync-to-host.sh -- push a directory to another machine (or pull it back)
# over SSH. Thin, explicit wrapper -- no config file, no magic: you always
# see exactly what rsync command ran.
#
# Usage:
#   rsync-to-host.sh push <local-dir> <host> [<remote-dir>]
#   rsync-to-host.sh pull <host> <remote-dir> <local-dir>
#
# Example:
#   rsync-to-host.sh push ~/dev/projects example-host ~/dev/projects
set -euo pipefail

usage() {
  echo "usage: rsync-to-host.sh push <local-dir> <host> [<remote-dir>]" >&2
  echo "       rsync-to-host.sh pull <host> <remote-dir> <local-dir>" >&2
  exit 1
}

mode="${1:-}"
case "$mode" in
  push)
    local_dir="${2:?local dir required}"
    host="${3:?host required}"
    remote_dir="${4:-$local_dir}"
    rsync -avz --progress --delete "$local_dir/" "$host:$remote_dir/"
    ;;
  pull)
    host="${2:?host required}"
    remote_dir="${3:?remote dir required}"
    local_dir="${4:?local dir required}"
    rsync -avz --progress --delete "$host:$remote_dir/" "$local_dir/"
    ;;
  *)
    usage
    ;;
esac
