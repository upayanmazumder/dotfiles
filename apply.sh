#!/usr/bin/env bash
# Apply this repo's tracked config onto $HOME, install packages, and put
# scripts/ on PATH. Existing changed files are never overwritten.
#
# Usage:
#   ./apply.sh              # packages + configs + scripts
#   ./apply.sh --configs    # configs only (skip pacman/paru)
#   ./apply.sh --packages   # packages only
#   ./apply.sh --scripts    # scripts symlinks only
#   ./apply.sh --replace-home .config/foo/bar  # reviewed file, with backup
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-all}"

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

install_packages() {
  log "pacman: installing packages/pacman.txt"
  mapfile -t pkgs < <(grep -vE '^\s*#|^\s*$' "$SCRIPT_DIR/packages/pacman.txt")
  sudo pacman -S --needed --noconfirm "${pkgs[@]}"

  log "pacman: installing packages/hardware.txt"
  mapfile -t hw < <(grep -vE '^\s*#|^\s*$' "$SCRIPT_DIR/packages/hardware.txt")
  sudo pacman -S --needed --noconfirm "${hw[@]}"

  if command -v paru >/dev/null 2>&1; then
    log "paru: installing packages/aur.txt"
    mapfile -t aur < <(grep -vE '^\s*#|^\s*$' "$SCRIPT_DIR/packages/aur.txt")
    paru -S --needed --noconfirm "${aur[@]}"
  else
    log "paru not found -- skipping packages/aur.txt (install paru first)"
  fi
}

apply_configs() {
  log "copying new home/ files into \$HOME (changed files are skipped)"
  find "$SCRIPT_DIR/home" -type f | while IFS= read -r src; do
    rel="${src#"$SCRIPT_DIR"/home/}"
    dest="$HOME/$rel"
    if [ -e "$dest" ] || [ -L "$dest" ]; then
      if cmp -s "$src" "$dest"; then
        continue
      fi
      log "  skipped changed $rel (review and merge manually)"
      continue
    fi
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    if [[ "$rel" == .ssh/* ]]; then
      chmod 700 "$HOME/.ssh"
      chmod 600 "$dest"
    fi
    log "  $rel"
  done
}

replace_home() {
  [ "$#" -eq 1 ] || { echo "usage: $0 --replace-home <home-relative-path>" >&2; exit 2; }
  local rel="$1" src dest backup
  case "$rel" in
    ""|/*|*..*|.config/hotspot/*|.ssh/*|.gitconfig|.config/git/*|\
    .config/zed/settings.json|.claude/settings.json|.codex/*|\
    .config/rclone/*|*credential*|*secret*|*token*|*password*)
      echo "refusing unreviewed or private path: $rel" >&2; exit 2 ;;
  esac
  src="$SCRIPT_DIR/home/$rel"
  dest="$HOME/$rel"
  [ -f "$src" ] && [ ! -L "$src" ] || { echo "not a tracked regular file: $rel" >&2; exit 2; }
  git -C "$SCRIPT_DIR" ls-files --error-unmatch -- "home/$rel" >/dev/null ||
    { echo "not tracked: $rel" >&2; exit 2; }
  [ ! -L "$dest" ] || { echo "refusing symlink target: $rel" >&2; exit 2; }
  if [ -f "$dest" ] && cmp -s "$src" "$dest"; then return; fi
  if [ -e "$dest" ]; then
    backup="$SCRIPT_DIR/.apply-backups/$(date +%Y%m%d-%H%M%S)-$$/$rel"
    mkdir -p "$(dirname "$backup")"
    cp -p "$dest" "$backup"
    log "  backed up $rel"
  fi
  mkdir -p "$(dirname "$dest")"
  cp -p "$src" "$dest"
  log "  deployed $rel"
}

apply_etc() {
  # Install tracked etc/ and usr/ files only when absent; never replace
  # live changes. Files with the executable bit in git install as 755.
  log "copying new etc/ and usr/ files into the system (changed files are skipped)"
  local tree src rel dest mode
  for tree in etc usr; do
    [ -d "$SCRIPT_DIR/$tree" ] || continue
    while IFS= read -r src; do
      rel="${src#"$SCRIPT_DIR"/}"
      dest="/$rel"
      if sudo test -e "$dest" || sudo test -L "$dest"; then
        if sudo cmp -s "$src" "$dest"; then
          continue
        fi
        log "  skipped changed $rel (review and merge manually)"
        continue
      fi
      mode=644
      [ -x "$src" ] && mode=755
      sudo install -Dm "$mode" -o root -g root "$src" "$dest"
      log "  $rel"
    done < <(find "$SCRIPT_DIR/$tree" -type f)
  done
}

link_scripts() {
  log "symlinking scripts/*/*.sh into ~/Scripts/bin"
  mkdir -p "$HOME/Scripts/bin"
  find "$SCRIPT_DIR/scripts" -mindepth 2 -maxdepth 2 -type f -name '*.sh' | while IFS= read -r src; do
    name="$(basename "$src" .sh)"
    dest="$HOME/Scripts/bin/$name"
    if [ "$name" = hotspot ] && [ ! -f "${XDG_CONFIG_HOME:-$HOME/.config}/hotspot/credentials" ]; then
      log "  skipped hotspot: create ~/.config/hotspot/credentials first"
      continue
    fi
    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
      continue
    fi
    if [ -e "$dest" ] || [ -L "$dest" ]; then
      log "  skipped changed ~/Scripts/bin/$name"
      continue
    fi
    ln -s "$src" "$dest"
    log "  $name -> $src"
  done
}

case "$MODE" in
  all)        install_packages; apply_configs; apply_etc; link_scripts ;;
  --configs)  apply_configs; apply_etc ;;
  --packages) install_packages ;;
  --scripts)  link_scripts ;;
  --replace-home) replace_home "${@:2}" ;;
  *) echo "usage: $0 [--configs|--packages|--scripts|--replace-home PATH]" >&2; exit 1 ;;
esac

log "done"
