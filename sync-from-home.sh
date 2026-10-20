#!/usr/bin/env bash
# Preview changed tracked home files without copying by default. To import
# one reviewed file, run ./sync-from-home.sh --pull .config/path/to/file.
# Private paths and content with credential indicators are never imported.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mode="${1:-}"
case "$mode" in
  ""|--dry-run)
    [ "$#" -le 1 ] || { echo "usage: $0 [--dry-run|--pull <home-relative-path>]" >&2; exit 2; }
    ;;
  --pull)
    [ "$#" -eq 2 ] || { echo "usage: $0 --pull <home-relative-path>" >&2; exit 2; }
    selected="${2#home/}"
    ;;
  *) echo "usage: $0 [--dry-run|--pull <home-relative-path>]" >&2; exit 2 ;;
esac

cd "$SCRIPT_DIR"
seen=0
while IFS= read -r -d '' path; do
  rel="${path#home/}"
  if [ "$mode" = "--pull" ]; then
    [ "$selected" = "$rel" ] || continue
    seen=1
  fi
  tracked="$SCRIPT_DIR/$path"
  case "${rel,,}" in
    .gitconfig|.ssh/*|.config/git/*|.config/zed/settings.json|\
    .config/kdeconnect/*|.claude/settings.json|.codex/*|\
    .config/hotspot/*|.config/rclone/*|.local/bin/rclone-sync-*|\
    .local/share/keyrings/*|*secret*|*token*|*password*|\
    *credential*|*private*|*.key|*.pem)
      printf '\033[1;33mprivate\033[0m %s (never sync from live)\n' "$rel"
      [ "$mode" != "--pull" ] || exit 1
      continue ;;
  esac
  [ -f "$tracked" ] && [ ! -L "$tracked" ] || continue
  live="$HOME/$rel"
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
  if [ -n "$(git status --porcelain -- "$path")" ]; then
    printf 'refusing %s: local repo version is already changed\n' "$rel" >&2
    exit 1
  fi
  # A selected file still needs human review: names and simple heuristics
  # cannot prove a file free of secrets. Fail closed on obvious indicators.
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
done < <(git ls-files -z -- home/)
if [ "$mode" = "--pull" ] && [ "$seen" -eq 0 ]; then
  printf 'not tracked under home/: %s\n' "$selected" >&2
  exit 2
fi

git status --short -- home/
