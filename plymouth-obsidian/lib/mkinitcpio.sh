#!/usr/bin/env bash
# mkinitcpio.sh — HOOKS array management, theme selection, initramfs rebuild.

# configure_mkinitcpio_hooks — idempotently inserts the `plymouth` hook into
# /etc/mkinitcpio.conf, honoring:
#   - systemd hook must precede plymouth (Arch wiki)
#   - plymouth must precede encrypt / sd-encrypt
# Detects HOOKS as a single-line array; aborts with guidance for the (rare)
# multi-line case rather than risking a bad edit.
configure_mkinitcpio_hooks() {
    log_step "Configuring mkinitcpio HOOKS"
    [[ -f "$MKINITCPIO_CONF" ]] || die "$MKINITCPIO_CONF not found"

    local hooks_line
    hooks_line="$(grep -E '^HOOKS=\(' "$MKINITCPIO_CONF" || true)"
    [[ -n "$hooks_line" ]] || die "Could not find a single-line HOOKS=(...) in $MKINITCPIO_CONF — edit it manually and re-run."

    local inner
    inner="$(sed -E 's/^HOOKS=\((.*)\)\s*$/\1/' <<< "$hooks_line")"
    local -a hooks=($inner)

    local h idx_plymouth=-1 idx_anchor=-1 idx_encrypt=-1 i=0
    for h in "${hooks[@]}"; do
        [[ "$h" == "plymouth" ]] && idx_plymouth=$i
        [[ "$h" == "systemd" && $idx_anchor -lt 0 ]] && idx_anchor=$i
        [[ "$h" == "udev" && $idx_anchor -lt 0 ]] && idx_anchor=$i
        [[ ( "$h" == "encrypt" || "$h" == "sd-encrypt" ) && $idx_encrypt -lt 0 ]] && idx_encrypt=$i
        i=$((i + 1))
    done

    if [[ $idx_plymouth -ge 0 && $idx_anchor -ge 0 && $idx_plymouth -gt $idx_anchor \
          && ( $idx_encrypt -lt 0 || $idx_plymouth -lt $idx_encrypt ) ]]; then
        log_ok "'plymouth' hook already present and correctly ordered"
        return 0
    fi

    # Remove any existing (possibly misplaced) plymouth entry, then reinsert.
    local -a filtered=()
    for h in "${hooks[@]}"; do
        [[ "$h" == "plymouth" ]] && continue
        filtered+=("$h")
    done

    if [[ $idx_anchor -lt 0 ]]; then
        [[ "${filtered[0]}" == "base" ]] || die "Unexpected HOOKS layout (no 'base', 'udev' or 'systemd' hook found) — edit $MKINITCPIO_CONF manually."
        idx_anchor=0
    else
        # Recompute anchor index against the filtered array (plymouth removal
        # only shifts indices if plymouth was before the anchor, which the
        # early-return above already excluded).
        idx_anchor=-1
        i=0
        for h in "${filtered[@]}"; do
            [[ "$h" == "systemd" ]] && { idx_anchor=$i; break; }
            i=$((i + 1))
        done
        if [[ $idx_anchor -lt 0 ]]; then
            i=0
            for h in "${filtered[@]}"; do
                [[ "$h" == "udev" ]] && { idx_anchor=$i; break; }
                i=$((i + 1))
            done
        fi
    fi

    local -a new_hooks=("${filtered[@]:0:idx_anchor+1}" "plymouth" "${filtered[@]:idx_anchor+1}")
    local new_line="HOOKS=(${new_hooks[*]})"

    backup_file "$MKINITCPIO_CONF"
    if [[ "$DRY_RUN" == "1" ]]; then
        log_info "[dry-run] $new_line"
    else
        sed -i -E "s|^HOOKS=\(.*\)\s*\$|${new_line}|" "$MKINITCPIO_CONF"
        log_ok "HOOKS updated: $new_line"
    fi
}

# set_plymouth_theme — writes [Daemon] Theme=obsidian to plymouthd.conf
# without invoking plymouth-set-default-theme's own rebuild (the caller
# rebuilds once, after every config change, via rebuild_initramfs).
set_plymouth_theme() {
    log_step "Setting default Plymouth theme to '${THEME_NAME}'"
    command -v plymouth-set-default-theme >/dev/null 2>&1 \
        || die "plymouth-set-default-theme not found — is the 'plymouth' package installed?"

    local previous
    previous="$(plymouth-set-default-theme 2>/dev/null || true)"
    if [[ "$previous" == "$THEME_NAME" ]]; then
        log_ok "theme already set to '${THEME_NAME}'"
        return 0
    fi

    [[ -n "$previous" ]] && state_set previous_theme "$previous"
    backup_file "$PLYMOUTHD_CONF"
    run "plymouth-set-default-theme ${THEME_NAME}" -- plymouth-set-default-theme "$THEME_NAME"
}

rebuild_initramfs() {
    log_step "Rebuilding initramfs (mkinitcpio -P)"
    command -v mkinitcpio >/dev/null 2>&1 || die "mkinitcpio not found"
    run "mkinitcpio -P" -- mkinitcpio -P
}
