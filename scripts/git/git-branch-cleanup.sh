#!/usr/bin/env bash
# git-branch-cleanup.sh -- delete local branches already merged into the
# repo's default branch, excluding the default branch itself and any branch
# passed via --keep.
#
# Usage: run inside a git repo:
#   git-branch-cleanup.sh [--keep branch1,branch2] [--dry-run]
set -euo pipefail

dry_run=0
keep=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry_run=1; shift ;;
    --keep) keep="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "not a git repo" >&2; exit 1; }

default_branch="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@')"
default_branch="${default_branch:-main}"
current_branch="$(git rev-parse --abbrev-ref HEAD)"

IFS=',' read -ra keep_list <<< "$keep"
keep_list+=("$default_branch" "$current_branch" "master" "develop")

is_kept() {
  local b="$1"
  for k in "${keep_list[@]}"; do
    [ "$b" = "$k" ] && return 0
  done
  return 1
}

merged="$(git branch --merged "$default_branch" --format='%(refname:short)')"
to_delete=()
while IFS= read -r branch; do
  [ -z "$branch" ] && continue
  is_kept "$branch" || to_delete+=("$branch")
done <<< "$merged"

if [ "${#to_delete[@]}" -eq 0 ]; then
  echo "nothing to clean up"
  exit 0
fi

echo "branches merged into $default_branch, safe to delete:"
printf '  %s\n' "${to_delete[@]}"

if [ "$dry_run" -eq 1 ]; then
  echo "--dry-run: not deleting"
  exit 0
fi

git branch -d "${to_delete[@]}"
