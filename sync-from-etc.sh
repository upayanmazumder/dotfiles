#!/usr/bin/env bash
# Preview changed tracked system files (etc/ and usr/) without copying by
# default. Import one reviewed file with ./sync-from-etc.sh --pull default/grub
# or --pull usr/share/.... Secret-bearing paths and content never enter this repo.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mode="${1:-}"
case "$mode" in
  ""|--dry-run)
    [ "$#" -le 1 ] || { echo "usage: $0 [--dry-run|--pull <etc-relative-path>]" >&2; exit 2; }
    ;;
  --pull)
    [ "$#" -eq 2 ] || { echo "usage: $0 --pull <etc-relative-path>" >&2; exit 2; }
    selected="${2#etc/}"
    ;;
  *) echo "usage: $0 [--dry-run|--pull <etc-relative-path>]" >&2; exit 2 ;;
esac

cd "$SCRIPT_DIR"
seen=0
while IFS= read -r -d '' rel; do
  if [ "$mode" = "--pull" ]; then
    [ "$selected" = "${rel#etc/}" ] || continue
    seen=1
  fi
  tracked="$SCRIPT_DIR/$rel"
  case "${rel,,}" in
    *secret*|*token*|*password*|*credential*|*private*|*.key|*.pem)
      printf '\033[1;33mprivate\033[0m %s (never sync from live)\n' "$rel"
      [ "$mode" != "--pull" ] || exit 1
      continue ;;
  esac
  [ -f "$tracked" ] && [ ! -L "$tracked" ] || continue
  live="/$rel"
  if [ ! -f "$live" ] || [ -L "$live" ]; then
    printf '\033[1;33mgone\033[0m  %s (missing or symlinked live file; unchanged in repo)\n' "$rel"
    [ "$mode" != "--pull" ] || exit 1
    continue
  fi
  if cmp -s "$tracked" "$live"; then
    continue
  fi
  if [ "$mode" != "--pull" ]; then
    printf 'would pull %s (review live file before --pull)\n' "$rel"
    continue
  fi
  if [ -n "$(git status --porcelain -- "$rel")" ]; then
    printf 'refusing %s: local repo version is already changed\n' "$rel" >&2
    exit 1
  fi
  if LC_ALL=C grep -Eiq -- \
    '(api[_-]?key|access[_-]?key|token|secret|pass(word|phrase)|credential|private[_-]?key|authorization|bearer|github_pat_|ghp_[[:alnum:]]{20,}|sk-[[:alnum:]]{20,}|AKIA[[:upper:]0-9]{16})' "$live"; then
    printf 'refusing %s: possible credential content; review manually\n' "$rel" >&2
    exit 1
  else
    scan_status=$?
    if [ "$scan_status" -ne 1 ]; then
      printf 'refusing %s: unable to scan live file\n' "$rel" >&2
      exit 1
    fi
  fi
  cp "$live" "$tracked"
  printf '\033[1;32mpulled\033[0m %s\n' "$rel"
done < <(git ls-files -z -- etc/ usr/)
if [ "$mode" = "--pull" ] && [ "$seen" -eq 0 ]; then
  printf 'not tracked under etc/ or usr/: %s\n' "$selected" >&2
  exit 2
fi

git status --short -- etc/ usr/
