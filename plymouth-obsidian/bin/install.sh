#!/usr/bin/env bash
# install.sh — install and activate the "obsidian" Plymouth theme.
#
# Usage:
#   sudo ./bin/install.sh [--dry-run] [--yes] [--no-package-install]
#
# Idempotent: safe to re-run. Every mutated file is backed up under
# /var/backups/plymouth-obsidian/<timestamp>/ before being touched, and a
# manifest is written so bin/uninstall.sh can restore this machine's exact
# prior state.
set -euo pipefail

LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../lib" && pwd)"
# shellcheck source=lib/common.sh
source "${LIB_DIR}/common.sh"
# shellcheck source=lib/bootloader.sh
source "${LIB_DIR}/bootloader.sh"
# shellcheck source=lib/mkinitcpio.sh
source "${LIB_DIR}/mkinitcpio.sh"
# shellcheck source=lib/verify.sh
source "${LIB_DIR}/verify.sh"

SKIP_PACKAGE_INSTALL=0

usage() {
    cat <<'EOF'
Usage: sudo ./bin/install.sh [options]

Options:
  --dry-run              Print every change without touching the system.
  --yes, -y              Assume "yes" to prompts (also passes --noconfirm to pacman).
  --no-package-install   Skip `pacman -S plymouth`; assume it is already installed.
  --help, -h             Show this help.
EOF
}

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --yes|-y) ASSUME_YES=1 ;;
        --no-package-install) SKIP_PACKAGE_INSTALL=1 ;;
        --help|-h) usage; exit 0 ;;
        *) die "Unknown option: $arg (see --help)" ;;
    esac
done

install_plymouth_package() {
    [[ $SKIP_PACKAGE_INSTALL -eq 1 ]] && return 0
    if pacman -Qi plymouth >/dev/null 2>&1; then
        log_ok "plymouth package already installed"
        return 0
    fi
    log_step "Installing plymouth"
    local -a pac=(pacman -S --needed plymouth)
    [[ "$ASSUME_YES" == "1" ]] && pac+=(--noconfirm)
    run "pacman -S --needed plymouth" -- "${pac[@]}"
}

copy_theme_files() {
    log_step "Installing theme files to ${THEME_DEST_DIR}"
    local marker="${THEME_DEST_DIR}/.obsidian-managed"

    if [[ -d "$THEME_DEST_DIR" && ! -f "$marker" ]]; then
        log_warn "${THEME_DEST_DIR} exists and was not created by this installer — backing it up in full"
        backup_file "$THEME_DEST_DIR"
        [[ "$DRY_RUN" == "1" ]] || rm -rf -- "$THEME_DEST_DIR"
    fi

    if [[ "$DRY_RUN" == "1" ]]; then
        log_info "[dry-run] sync ${THEME_SRC_DIR}/theme/${THEME_NAME}/ -> ${THEME_DEST_DIR}/"
        return 0
    fi

    mkdir -p "$THEME_DEST_DIR"
    if command -v rsync >/dev/null 2>&1; then
        rsync -a --delete --exclude '.obsidian-managed' "${THEME_SRC_DIR}/theme/${THEME_NAME}/" "${THEME_DEST_DIR}/"
    else
        find "$THEME_DEST_DIR" -mindepth 1 -delete
        cp -a "${THEME_SRC_DIR}/theme/${THEME_NAME}/." "${THEME_DEST_DIR}/"
    fi
    touch "$marker"
    log_ok "theme files installed"
}

main() {
    require_root
    require_arch
    detect_bootloader
    [[ "$BOOTLOADER" == "none" ]] && die "No supported bootloader detected (GRUB or systemd-boot required)."
    log_info "Detected bootloader: ${BOOTLOADER}"

    init_session_backup_dir
    mkdir -p "$STATE_DIR"
    [[ -z "$(state_get first_backup_dir)" ]] && state_set first_backup_dir "$SESSION_BACKUP_DIR"

    install_plymouth_package
    copy_theme_files
    set_plymouth_theme
    configure_mkinitcpio_hooks
    configure_bootloader
    rebuild_initramfs

    if [[ "$DRY_RUN" == "1" ]]; then
        echo
        log_ok "Dry run complete — no files were changed."
        return 0
    fi

    state_set bootloader "$BOOTLOADER"
    state_set backup_dir "$SESSION_BACKUP_DIR"
    state_set installed_at "$SESSION_TS"

    echo
    if verify_installation; then
        echo
        log_ok "Obsidian theme installed. Reboot to see it."
        log_info "Preview any time from a TTY with: sudo plymouthd; sudo plymouth --show-splash; sleep 5; sudo plymouth --quit"
    else
        echo
        log_err "Installation completed but verification found issues — review the log above."
        exit 1
    fi
}

main "$@"
