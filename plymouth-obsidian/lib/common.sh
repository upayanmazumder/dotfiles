#!/usr/bin/env bash
# common.sh — shared logging, privilege, backup and command helpers.
#
# Sourced by bin/install.sh and bin/uninstall.sh. Never executed directly.
#
# Every path below can be overridden via a pre-set environment variable
# (used by tests/ to point the whole installer at a throwaway fake root
# instead of the real system — see tests/run_tests.sh).

# --- Identity --------------------------------------------------------------
THEME_NAME="obsidian"
THEME_SRC_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
: "${THEME_DEST_DIR:=/usr/share/plymouth/themes/${THEME_NAME}}"
: "${PLYMOUTHD_CONF:=/etc/plymouth/plymouthd.conf}"
: "${MKINITCPIO_CONF:=/etc/mkinitcpio.conf}"
: "${GRUB_DEFAULTS:=/etc/default/grub}"
: "${GRUB_CFG:=/boot/grub/grub.cfg}"
: "${KERNEL_CMDLINE_FILE:=/etc/kernel/cmdline}"
: "${SDBOOT_MANAGE_CONF:=/etc/sdboot-manage.conf}"
: "${BOOT_DIR:=/boot}"

: "${STATE_DIR:=/var/lib/plymouth-obsidian}"
: "${BACKUP_ROOT:=/var/backups/plymouth-obsidian}"
STATE_FILE="${STATE_DIR}/install-state"
SESSION_TS="$(date +%Y%m%d-%H%M%S%N)"
SESSION_BACKUP_DIR="${BACKUP_ROOT}/${SESSION_TS}"

REQUIRED_CMDLINE_PARAMS=(quiet splash loglevel=3 vt.global_cursor_default=0 rd.udev.log_priority=3)

DRY_RUN="${DRY_RUN:-0}"
ASSUME_YES="${ASSUME_YES:-0}"

# --- Logging -----------------------------------------------------------
if [[ -t 1 ]]; then
    C_RESET=$'\033[0m'; C_DIM=$'\033[2m'; C_RED=$'\033[31m'
    C_YELLOW=$'\033[33m'; C_GREEN=$'\033[32m'; C_BLUE=$'\033[34m'
else
    C_RESET=""; C_DIM=""; C_RED=""; C_YELLOW=""; C_GREEN=""; C_BLUE=""
fi

log_step()  { printf '%s==>%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
log_info()  { printf '%s ->%s %s\n' "$C_DIM" "$C_RESET" "$*"; }
log_ok()    { printf '%s ok%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
log_warn()  { printf '%swarn%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
log_err()   { printf '%s!!%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
die()       { log_err "$*"; exit 1; }

# --- Privilege / environment checks ----------------------------------------
require_root() {
    [[ $EUID -eq 0 ]] || die "Must be run as root (try: sudo $0 $*)"
}

require_arch() {
    command -v pacman >/dev/null 2>&1 || die "pacman not found — this installer targets Arch-based systems (CachyOS)."
}

# --- Dry-run aware execution --------------------------------------------
# run <description> -- <command...>
run() {
    local desc="$1"; shift
    [[ "$1" == "--" ]] && shift
    if [[ "$DRY_RUN" == "1" ]]; then
        log_info "[dry-run] $desc: $*"
        return 0
    fi
    log_info "$desc"
    "$@"
}

confirm() {
    local prompt="$1"
    [[ "$ASSUME_YES" == "1" ]] && return 0
    local reply
    read -r -p "$prompt [y/N] " reply </dev/tty || return 1
    [[ "$reply" =~ ^[Yy]$ ]]
}

# --- Backups -----------------------------------------------------------
# backup_file <absolute-path>
# Copies the file (if it exists) into this session's backup dir, preserving
# its path relative to /, and appends a restore entry to the manifest.
backup_file() {
    local src="$1"
    [[ -e "$src" ]] || return 0
    local dest="${SESSION_BACKUP_DIR}${src}"
    mkdir -p "$(dirname -- "$dest")"
    cp -a -- "$src" "$dest"
    echo "$src" >> "${SESSION_BACKUP_DIR}/manifest.txt"
    log_info "backed up $src -> $dest"
}

init_session_backup_dir() {
    mkdir -p "$SESSION_BACKUP_DIR"
    : > "${SESSION_BACKUP_DIR}/manifest.txt"
    ln -sfn "$SESSION_BACKUP_DIR" "${BACKUP_ROOT}/latest"
}

# --- Persistent state (used by uninstall.sh) --------------------------
state_set() {
    mkdir -p "$STATE_DIR"
    local key="$1" val="$2"
    touch "$STATE_FILE"
    grep -v "^${key}=" "$STATE_FILE" > "${STATE_FILE}.tmp" 2>/dev/null || : > "${STATE_FILE}.tmp"
    printf '%s=%q\n' "$key" "$val" >> "${STATE_FILE}.tmp"
    mv "${STATE_FILE}.tmp" "$STATE_FILE"
}

state_get() {
    local key="$1" default="${2:-}"
    [[ -f "$STATE_FILE" ]] || { printf '%s' "$default"; return; }
    local line
    line="$(grep "^${key}=" "$STATE_FILE" 2>/dev/null | tail -n1 | cut -d= -f2- || true)"
    if [[ -z "$line" ]]; then printf '%s' "$default"; else eval "printf '%s' $line"; fi
}
