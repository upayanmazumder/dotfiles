#!/usr/bin/env bash
# project-open.sh -- fuzzy project picker for this machine's git checkouts.
#
# Solves a real daily friction: the actual dev tree is ~/dev/<owner>/<repo>
# (28 repos as of 2026-09-15), so "work on project X" meant typing a
# two-level path from memory before `zeditor .`. This lists every git checkout
# across both trees, most-recently-touched first, and opens it.
#
# Both trees are indexed.
#
# Ordering is by .git directory mtime -- a cheap proxy for "recently worked
# on" that costs one stat() per repo, instead of shelling out to
# `git log -1` 28 times just to sort a menu.
#
# Usage:
#   project-open.sh            # pick a project, open editor + terminal
#   project-open.sh --editor   # editor only
#   project-open.sh --term     # terminal only
#   project-open.sh --print    # print the chosen path, open nothing
#                              #   (for composing: cd "$(project-open --print)")
set -euo pipefail

TREES=("$HOME/dev" "$HOME/Code")
MAXDEPTH=3          # ~/dev/<owner>/<repo>/.git is depth 3 from ~/dev
mode="both"

case "${1:-}" in
  --editor) mode="editor" ;;
  --term)   mode="term" ;;
  --print)  mode="print" ;;
  "")       ;;
  *) echo "usage: $(basename "$0") [--editor|--term|--print]" >&2; exit 2 ;;
esac

command -v fuzzel >/dev/null 2>&1 || { echo "fuzzel not found" >&2; exit 1; }

# Collect "<mtime>\t<label>\t<path>" for every git checkout in both trees.
# -prune stops us from descending into a repo's own .git or nested modules.
collect() {
  local tree sigil
  for tree in "${TREES[@]}"; do
    [ -d "$tree" ] || continue
    case "$tree" in
      "$HOME/dev")  sigil="dev" ;;
      "$HOME/Code") sigil="code" ;;
      *)            sigil="$(basename "$tree")" ;;
    esac
    find "$tree" -maxdepth "$MAXDEPTH" -type d -name .git -prune \
         -printf '%T@\t%h\n' 2>/dev/null |
    while IFS=$'\t' read -r mtime path; do
      printf '%s\t%s  %s\t%s\n' "${mtime%%.*}" "$sigil" "${path#"$tree"/}" "$path"
    done
  done
}

entries="$(collect | sort -rn -k1,1)"
[ -n "$entries" ] || { echo "no git checkouts found under: ${TREES[*]}" >&2; exit 1; }

# Show only the label column to fuzzel; map the selection back to a path.
choice="$(cut -f2 <<<"$entries" |
  fuzzel --dmenu --match-mode fzf --prompt 'project> ' \
         --placeholder 'fuzzy-match a repo' 2>/dev/null)" || exit 0
[ -n "$choice" ] || exit 0

path="$(awk -F'\t' -v c="$choice" '$2==c{print $3; exit}' <<<"$entries")"
[ -n "$path" ] && [ -d "$path" ] || { echo "could not resolve: $choice" >&2; exit 1; }

if [ "$mode" = "print" ]; then
  printf '%s\n' "$path"
  exit 0
fi

# setsid+nohup rather than `hyprctl dispatch exec`: Hyprland 0.56's Lua
# config layer parses dispatch arguments as Lua, which mangles paths and
# bracketed rule prefixes (see docs/machine.md "Scratchpads").
spawn() { setsid nohup "$@" >/dev/null 2>&1 & }

# Both windows open on the current workspace: the semantic workspace pins were
# removed from ~/.config/hypr/custom/rules.lua on 2026-09-16, deliberately, so
# that the editor and its terminal stay together wherever you are.
if [ "$mode" = "both" ] || [ "$mode" = "editor" ]; then
  # `zeditor`, not `zed`: Arch's zed package installs /usr/bin/zeditor.
  # Unlike `code <path>`, Zed is not single-instance in the same way, so
  # re-opening an already-open project does not silently focus a window on
  # another workspace (see docs/machine.md).
  if command -v zeditor >/dev/null 2>&1; then
    spawn zeditor "$path"
  else
    echo "zeditor not found; skipping editor" >&2
  fi
fi

if [ "$mode" = "both" ] || [ "$mode" = "term" ]; then
  if command -v kitty >/dev/null 2>&1; then
    spawn kitty --directory "$path"
  else
    echo "kitty not found; skipping terminal" >&2
  fi
fi
