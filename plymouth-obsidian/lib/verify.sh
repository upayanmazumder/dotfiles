#!/usr/bin/env bash
# verify.sh — post-install verification. Prints a pass/fail report and
# returns non-zero if anything required is missing.

verify_installation() {
    log_step "Verifying installation"
    local failures=0

    _check() {
        local desc="$1" ok="$2"
        if [[ "$ok" == "1" ]]; then
            log_ok "$desc"
        else
            log_err "$desc"
            failures=$((failures + 1))
        fi
    }

    # Theme files on disk.
    local f ok=1
    for f in "${THEME_NAME}.plymouth" "${THEME_NAME}.script" \
             assets/ring.png assets/dot.png assets/pixel_black.png assets/pixel_accent.png; do
        [[ -f "${THEME_DEST_DIR}/${f}" ]] || ok=0
    done
    _check "theme files present in ${THEME_DEST_DIR}" "$ok"

    # Active theme.
    local active
    active="$(plymouth-set-default-theme 2>/dev/null || true)"
    _check "plymouthd.conf selects '${THEME_NAME}' (found: '${active:-none}')" "$([[ "$active" == "$THEME_NAME" ]] && echo 1 || echo 0)"

    # HOOKS array.
    ok=0
    grep -qE '^HOOKS=\(.*\bplymouth\b.*\)' "$MKINITCPIO_CONF" 2>/dev/null && ok=1
    _check "'plymouth' present in $MKINITCPIO_CONF HOOKS" "$ok"

    # Theme actually packaged into the built initramfs.
    local img
    img="$(_primary_initramfs_image)"
    if [[ -n "$img" && -f "$img" ]] && command -v lsinitcpio >/dev/null 2>&1; then
        ok=0
        lsinitcpio "$img" 2>/dev/null | grep -q "usr/share/plymouth/themes/${THEME_NAME}/${THEME_NAME}.script" && ok=1
        _check "theme packaged into $(basename -- "$img")" "$ok"
    else
        log_warn "skipped initramfs content check (no image found or lsinitcpio missing)"
    fi

    # Kernel command line carries the required parameters.
    ok=0
    case "$BOOTLOADER" in
        grub)
            [[ -f "$GRUB_CFG" ]] && grep -q 'quiet' "$GRUB_CFG" && grep -q 'splash' "$GRUB_CFG" && ok=1
            ;;
        systemd-boot-cachyos)
            grep -qE '^LINUX_OPTIONS="[^"]*quiet' "$SDBOOT_MANAGE_CONF" 2>/dev/null && ok=1
            ;;
        systemd-boot)
            local esp entries_dir
            esp="$(esp_path)"; entries_dir="${esp}/loader/entries"
            if [[ -d "$entries_dir" ]]; then
                for f in "$entries_dir"/*.conf; do
                    [[ -e "$f" ]] || continue
                    [[ "$(basename -- "$f")" == *fallback* ]] && continue
                    grep -q '^options.*quiet' "$f" && grep -q 'splash' "$f" && ok=1 && break
                done
            fi
            ;;
    esac
    _check "kernel command line carries 'quiet splash' (bootloader: ${BOOTLOADER})" "$ok"

    unset -f _check
    if [[ $failures -eq 0 ]]; then
        log_ok "All checks passed."
        return 0
    fi
    log_err "${failures} check(s) failed — see above."
    return 1
}

# _primary_initramfs_image — best-effort path to the running kernel's
# non-fallback initramfs image.
_primary_initramfs_image() {
    local rel_ver
    rel_ver="$(uname -r 2>/dev/null || true)"
    local cand
    for cand in "${BOOT_DIR}/initramfs-${rel_ver}.img" "${BOOT_DIR}/initramfs-linux.img" "${BOOT_DIR}/initramfs-linux-cachyos.img"; do
        [[ -f "$cand" ]] && { printf '%s' "$cand"; return; }
    done
    # Fall back to the first non-fallback initramfs-*.img found.
    for cand in "${BOOT_DIR}"/initramfs-*.img; do
        [[ -f "$cand" ]] || continue
        [[ "$cand" == *fallback* ]] && continue
        printf '%s' "$cand"
        return
    done
}
