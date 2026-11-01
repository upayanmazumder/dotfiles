#!/usr/bin/env bash
# uninstall.sh — remove the "obsidian" Plymouth theme and restore the
# system's prior boot-splash configuration from the backups install.sh made.
#
# Usage:
#   sudo ./bin/uninstall.sh [--dry-run] [--yes] [--purge]
#
# Idempotent: safe to run when already uninstalled (reports and exits 0).
set -euo pipefail

LIB_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../lib" && pwd)"
# shellcheck source=lib/common.sh
source "${LIB_DIR}/common.sh"
# shellcheck source=lib/bootloader.sh
source "${LIB_DIR}/bootloader.sh"
# shellcheck source=lib/mkinitcpio.sh
source "${LIB_DIR}/mkinitcpio.sh"

PURGE=0

usage() {
    cat <<'EOF'
Usage: sudo ./bin/uninstall.sh [options]

Options:
  --dry-run   Print every change without touching the system.
  --yes, -y   Assume "yes" to prompts.
  --purge     Also delete backup archives and installer state afterward.
  --help, -h  Show this help.
EOF
}

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --yes|-y) ASSUME_YES=1 ;;
        --purge) PURGE=1 ;;
        --help|-h) usage; exit 0 ;;
        *) die "Unknown option: $arg (see --help)" ;;
    esac
done

restore_mkinitcpio_conf() {
    local backup_dir="$1"
    if [[ -f "${backup_dir}${MKINITCPIO_CONF}" ]]; then
        run "restoring ${MKINITCPIO_CONF}" -- cp -a -- "${backup_dir}${MKINITCPIO_CONF}" "$MKINITCPIO_CONF"
    else
        log_info "no backup of ${MKINITCPIO_CONF} found (HOOKS were likely already correct) — leaving as-is"
    fi
}

restore_theme_selection() {
    local backup_dir="$1"
    if [[ -n "$backup_dir" && -f "${backup_dir}${PLYMOUTHD_CONF}" ]]; then
        run "restoring ${PLYMOUTHD_CONF}" -- cp -a -- "${backup_dir}${PLYMOUTHD_CONF}" "$PLYMOUTHD_CONF"
        return
    fi

    local prev
    prev="$(state_get previous_theme)"
    if [[ -n "$prev" ]]; then
        run "restoring previous theme '${prev}'" -- plymouth-set-default-theme "$prev"
    else
        log_warn "no prior theme recorded; leaving plymouthd.conf as-is (theme directory will still be removed)"
    fi
}

remove_theme_files() {
    local marker="${THEME_DEST_DIR}/.obsidian-managed"
    if [[ ! -d "$THEME_DEST_DIR" ]]; then
        log_ok "theme directory already absent"
        return 0
    fi
    if [[ ! -f "$marker" ]]; then
        log_warn "${THEME_DEST_DIR} has no installer marker — leaving it in place (not ours to delete)"
        return 0
    fi
    run "removing ${THEME_DEST_DIR}" -- rm -rf -- "$THEME_DEST_DIR"
}

main() {
    require_root
    require_arch

    if [[ ! -f "$STATE_FILE" && ! -d "$THEME_DEST_DIR" ]]; then
        log_ok "Obsidian theme is not installed — nothing to do."
        exit 0
    fi

    detect_bootloader
    local backup_dir
    backup_dir="$(state_get first_backup_dir)"
    [[ -z "$backup_dir" ]] && backup_dir="$(state_get backup_dir)"

    if [[ -z "$backup_dir" || ! -d "$backup_dir" ]]; then
        log_warn "No installer backup found — will reset theme selection and mkinitcpio hook manually, but cannot restore bootloader files to their exact pre-install byte contents."
        confirm "Continue uninstalling without a full backup?" || die "Aborted."
        backup_dir=""
    fi

    log_step "Restoring prior configuration"
    if [[ -n "$backup_dir" ]]; then
        restore_theme_selection "$backup_dir"
        restore_mkinitcpio_conf "$backup_dir"
        restore_bootloader_config "$backup_dir"
    else
        restore_theme_selection ""
        # Best-effort HOOKS cleanup: drop a bare 'plymouth' token if present.
        if grep -qE '^HOOKS=\(.*\bplymouth\b.*\)' "$MKINITCPIO_CONF" 2>/dev/null; then
            backup_file "$MKINITCPIO_CONF"
            [[ "$DRY_RUN" == "1" ]] || sed -i -E 's/\bplymouth[[:space:]]//' "$MKINITCPIO_CONF"
            log_ok "removed 'plymouth' from HOOKS"
        fi
    fi

    remove_theme_files
    rebuild_initramfs

    if [[ $PURGE -eq 1 ]]; then
        log_step "Purging backups and installer state"
        run "removing ${BACKUP_ROOT}" -- rm -rf -- "$BACKUP_ROOT"
        run "removing ${STATE_DIR}" -- rm -rf -- "$STATE_DIR"
    fi

    echo
    log_ok "Obsidian theme uninstalled. Reboot to confirm the prior boot splash is back."
    if [[ $PURGE -eq 0 ]]; then
        log_info "Backups retained under ${BACKUP_ROOT} (use --purge to remove them)."
    fi
}

main "$@"
