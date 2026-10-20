#!/usr/bin/env bash
# dev-palette.sh -- one fuzzy menu over this machine's actual dev/admin
# actions: SSH hosts, git, docker, kubernetes, and the utility scripts in
# this repo.
#
# Why this exists: `apply.sh --scripts` symlinks ten genuinely useful
# scripts into ~/Scripts/bin, where they are effectively invisible -- you
# have to already remember a script exists, and its exact name, to use it.
# This surfaces them (and the SSH hosts from ~/.ssh/config) in one
# fuzzy-searchable list. Type "ssh", "git", "k8s", "sys" to filter.
#
# Deliberately NOT a general command palette: the framework already has an
# app launcher (tap SUPER) and a keybind cheatsheet (SUPER+/). Duplicating
# either would be noise. This only covers things neither of those reach.
#
# Entries are built from what is actually present -- a missing tool or an
# absent ~/.ssh/config simply yields fewer rows, never a broken entry.
#
# Usage: dev-palette.sh        # normally bound to SUPER+SHIFT+Space
set -euo pipefail

command -v fuzzel >/dev/null 2>&1 || { echo "fuzzel not found" >&2; exit 1; }
BIN="$HOME/Scripts/bin"
SELF_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
PROJECT_OPEN="$SELF_DIR/project-open.sh"

# Run modes:
#   tui      interactive full-screen program; plain kitty window
#   report   prints and exits; kitty --hold so output stays readable
#   detach   no terminal wanted
have() { command -v "$1" >/dev/null 2>&1; }
rows=()
add() { rows+=("$1"$'\t'"$2"$'\t'"$3"); }   # label, mode, command

# ── SSH hosts (parsed live, so new hosts appear automatically) ──────────
if [ -r "$HOME/.ssh/config" ]; then
  while read -r host; do
    [ -n "$host" ] || continue
    hn="$(awk -v h="$host" '
      $1=="Host" {inb=($2==h)}
      inb && tolower($1)=="hostname" {print $2; exit}' "$HOME/.ssh/config")"
    add "ssh     $host${hn:+  ($hn)}" tui "ssh $host"
  done < <(awk '$1=="Host" && $2 !~ /[*?]/ {print $2}' "$HOME/.ssh/config")
fi

# ── git ─────────────────────────────────────────────────────────────────
# lazygit and branch-cleanup both need to run *inside* a repo, so they
# compose with project-open --print rather than guessing a directory.
if have lazygit && [ -x "$PROJECT_OPEN" ]; then
  add "git     lazygit (pick project)" tui \
      "p=\$(\"$PROJECT_OPEN\" --print) && cd \"\$p\" && lazygit"
fi
if [ -x "$BIN/git-branch-cleanup" ] && [ -x "$PROJECT_OPEN" ]; then
  add "git     prune merged branches (pick project)" report \
      "p=\$(\"$PROJECT_OPEN\" --print) && cd \"\$p\" && \"$BIN/git-branch-cleanup\""
fi

# ── docker ──────────────────────────────────────────────────────────────
have lazydocker            && add "docker  lazydocker" tui "lazydocker"
[ -x "$BIN/docker-prune-all" ] && add "docker  prune all (reclaim space)" report "\"$BIN/docker-prune-all\""

# ── kubernetes ──────────────────────────────────────────────────────────
if have kubectl && [ -x "$BIN/kctx" ]; then
  add "k8s     contexts"   report "\"$BIN/kctx\""
  add "k8s     namespaces" report "\"$BIN/kctx\" ns"
fi
have k9s && add "k8s     k9s" tui "k9s"

# ── system / maintenance ────────────────────────────────────────────────
[ -x "$BIN/system-report" ]   && add "sys     diagnostic report"        report "\"$BIN/system-report\""
[ -x "$BIN/pacman-cleanup" ]  && add "sys     pacman cleanup (orphans + cache)" report "\"$BIN/pacman-cleanup\""
[ -x "$BIN/mirror-refresh" ]  && add "sys     mirror refresh + full update"     report "\"$BIN/mirror-refresh\""
[ -x "$BIN/backup-code" ]     && add "sys     backup ~/dev + ~/Code + ~/Sync"    report "\"$BIN/backup-code\""
have btop                     && add "sys     btop (processes)"          tui "btop"
have duf                      && add "sys     disk usage"                report "duf"
add "sys     power profile" report 'printf "profile: %s\nAC online: %s\n" "$(powerprofilesctl get)" "$(cat /sys/class/power_supply/ADP1/online)"'

# ── network ─────────────────────────────────────────────────────────────
# apply.sh names symlinks with the .sh stripped, so this is "hotspot".
[ -x "$BIN/hotspot" ] && add "net     hotspot (on-demand AP)" tui "\"$BIN/hotspot\""

# ── desktop ─────────────────────────────────────────────────────────────
add "desk    restart quickshell" detach "killall qs quickshell 2>/dev/null; sleep 1; qs -c ii"
add "desk    reload hyprland"    detach "hyprctl reload"

# Deliberately excluded because they require arguments and would be broken
# menu entries: game-launch (Steam passes %command%) and rsync-to-host
# (needs explicit source/destination).

[ ${#rows[@]} -gt 0 ] || { echo "no actions available" >&2; exit 1; }

choice="$(printf '%s\n' "${rows[@]}" | cut -f1 |
  fuzzel --dmenu --match-mode fzf --prompt 'do> ' \
         --placeholder 'ssh / git / docker / k8s / sys / net / desk' 2>/dev/null)" || exit 0
[ -n "$choice" ] || exit 0

mode=""; cmd=""
for r in "${rows[@]}"; do
  IFS=$'\t' read -r l m c <<<"$r"
  if [ "$l" = "$choice" ]; then mode="$m"; cmd="$c"; break; fi
done
[ -n "$cmd" ] || { echo "could not resolve: $choice" >&2; exit 1; }

# setsid+nohup rather than `hyprctl dispatch exec`: Hyprland 0.56's Lua
# config layer parses dispatch arguments as Lua (see docs/machine.md).
case "$mode" in
  tui)    setsid nohup kitty        sh -c "$cmd" >/dev/null 2>&1 & ;;
  report) setsid nohup kitty --hold sh -c "$cmd" >/dev/null 2>&1 & ;;
  detach) setsid nohup sh -c "$cmd"              >/dev/null 2>&1 & ;;
esac
