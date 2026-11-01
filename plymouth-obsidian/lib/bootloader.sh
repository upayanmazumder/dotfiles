#!/usr/bin/env bash
# bootloader.sh — bootloader detection and kernel command-line management.
#
# Sourced by bin/install.sh / bin/uninstall.sh after lib/common.sh.
# Supports: GRUB, vanilla systemd-boot (Arch), and CachyOS's sdboot-manage.

# detect_bootloader — sets global BOOTLOADER to one of:
#   grub | systemd-boot-cachyos | systemd-boot | none
detect_bootloader() {
    BOOTLOADER="none"

    local active=""
    if command -v bootctl >/dev/null 2>&1 && [[ -d /sys/firmware/efi ]]; then
        active="$(bootctl status 2>/dev/null | grep -i '^ *Product:' | head -n1 || true)"
    fi

    local has_grub=0 has_sdboot=0
    [[ -f "$GRUB_DEFAULTS" ]] && command -v grub-mkconfig >/dev/null 2>&1 && has_grub=1
    [[ -f /boot/loader/loader.conf || -f /efi/loader/loader.conf ]] && has_sdboot=1

    if [[ $has_sdboot -eq 1 && $has_grub -eq 0 ]]; then
        BOOTLOADER="systemd-boot"
    elif [[ $has_grub -eq 1 && $has_sdboot -eq 0 ]]; then
        BOOTLOADER="grub"
    elif [[ $has_grub -eq 1 && $has_sdboot -eq 1 ]]; then
        # Both installed (common during a bootloader migration) — trust bootctl.
        if [[ "$active" == *systemd-boot* ]]; then
            BOOTLOADER="systemd-boot"
        else
            BOOTLOADER="grub"
        fi
    fi

    if [[ "$BOOTLOADER" == "systemd-boot" ]] && { [[ -f "$SDBOOT_MANAGE_CONF" ]] || command -v sdboot-manage >/dev/null 2>&1; }; then
        BOOTLOADER="systemd-boot-cachyos"
    fi

    export BOOTLOADER
}

# esp_path — resolve the ESP mountpoint (bootctl, then common fallbacks).
esp_path() {
    local p=""
    if command -v bootctl >/dev/null 2>&1; then
        p="$(bootctl -p 2>/dev/null || true)"
    fi
    if [[ -z "$p" ]]; then
        for cand in /efi /boot; do
            [[ -d "${cand}/loader/entries" || -d "${cand}/EFI" ]] && { p="$cand"; break; }
        done
    fi
    printf '%s' "${p:-/boot}"
}

# merge_cmdline_params <existing string> -> prints merged string with
# REQUIRED_CMDLINE_PARAMS appended if missing (idempotent, token-aware).
merge_cmdline_params() {
    local existing="$1"
    local -a tokens=($existing)
    local param needle found
    for param in "${REQUIRED_CMDLINE_PARAMS[@]}"; do
        needle="${param%%=*}"
        found=0
        for t in "${tokens[@]}"; do
            [[ "$t" == "$param" || "$t" == "${needle}="* ]] && { found=1; break; }
        done
        [[ $found -eq 0 ]] && tokens+=("$param")
    done
    printf '%s' "${tokens[*]}"
}

# --- GRUB --------------------------------------------------------------
configure_grub() {
    log_step "Configuring GRUB kernel parameters"
    backup_file "$GRUB_DEFAULTS"

    local current merged
    current="$(grep -E '^GRUB_CMDLINE_LINUX_DEFAULT=' "$GRUB_DEFAULTS" 2>/dev/null | head -n1 | sed -E 's/^GRUB_CMDLINE_LINUX_DEFAULT="?(.*)"?$/\1/' | sed -E 's/"$//' || true)"
    merged="$(merge_cmdline_params "$current")"

    if [[ "$merged" == "$current" ]]; then
        log_ok "GRUB_CMDLINE_LINUX_DEFAULT already contains required parameters"
    else
        if [[ "$DRY_RUN" == "1" ]]; then
            log_info "[dry-run] set GRUB_CMDLINE_LINUX_DEFAULT=\"$merged\""
        else
            if grep -qE '^GRUB_CMDLINE_LINUX_DEFAULT=' "$GRUB_DEFAULTS" 2>/dev/null; then
                sed -i -E "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"${merged}\"|" "$GRUB_DEFAULTS"
            else
                printf 'GRUB_CMDLINE_LINUX_DEFAULT="%s"\n' "$merged" >> "$GRUB_DEFAULTS"
            fi
            log_ok "updated GRUB_CMDLINE_LINUX_DEFAULT"
        fi
    fi

    [[ -f "$GRUB_CFG" ]] && backup_file "$GRUB_CFG"
    mkdir -p "$(dirname -- "$GRUB_CFG")"
    run "regenerating $GRUB_CFG" -- grub-mkconfig -o "$GRUB_CFG"
}

# --- systemd-boot (vanilla Arch: direct loader-entry editing) -------------
configure_systemd_boot_vanilla() {
    log_step "Configuring systemd-boot kernel parameters"
    local esp entries_dir
    esp="$(esp_path)"
    entries_dir="${esp}/loader/entries"

    if [[ -f "$KERNEL_CMDLINE_FILE" ]]; then
        backup_file "$KERNEL_CMDLINE_FILE"
        local current merged
        current="$(cat "$KERNEL_CMDLINE_FILE" 2>/dev/null)"
        merged="$(merge_cmdline_params "$current")"
        if [[ "$merged" != "$current" ]]; then
            if [[ "$DRY_RUN" == "1" ]]; then
                log_info "[dry-run] write $KERNEL_CMDLINE_FILE: $merged"
            else
                printf '%s\n' "$merged" > "$KERNEL_CMDLINE_FILE"
                log_ok "updated $KERNEL_CMDLINE_FILE"
            fi
        else
            log_ok "$KERNEL_CMDLINE_FILE already contains required parameters"
        fi
    fi

    [[ -d "$entries_dir" ]] || { log_warn "no loader entries found under $entries_dir"; return 0; }

    local f base current merged changed=0
    for f in "$entries_dir"/*.conf; do
        [[ -e "$f" ]] || continue
        base="$(basename -- "$f")"
        [[ "$base" == *fallback* ]] && { log_info "leaving $base untouched (fallback/recovery entry)"; continue; }

        current="$(grep -E '^options ' "$f" | head -n1 | sed -E 's/^options[[:space:]]+//' || true)"
        [[ -z "$current" ]] && { log_warn "$base has no 'options' line — skipping"; continue; }
        merged="$(merge_cmdline_params "$current")"
        if [[ "$merged" != "$current" ]]; then
            backup_file "$f"
            if [[ "$DRY_RUN" == "1" ]]; then
                log_info "[dry-run] $base options -> $merged"
            else
                sed -i -E "s|^options .*|options ${merged}|" "$f"
                log_ok "updated $base"
            fi
            changed=1
        fi
    done
    if [[ $changed -eq 0 ]]; then
        log_ok "loader entries already contain required parameters"
    fi
}

# --- systemd-boot (CachyOS: sdboot-manage) ------------------------------
configure_systemd_boot_cachyos() {
    log_step "Configuring systemd-boot kernel parameters (sdboot-manage)"
    backup_file "$SDBOOT_MANAGE_CONF"

    local current merged
    if [[ -f "$SDBOOT_MANAGE_CONF" ]]; then
        current="$(grep -E '^LINUX_OPTIONS=' "$SDBOOT_MANAGE_CONF" 2>/dev/null | head -n1 | sed -E 's/^LINUX_OPTIONS="?(.*)"?$/\1/' | sed -E 's/"$//' || true)"
    else
        current=""
    fi
    merged="$(merge_cmdline_params "$current")"

    if [[ "$merged" == "$current" && -f "$SDBOOT_MANAGE_CONF" ]]; then
        log_ok "LINUX_OPTIONS already contains required parameters"
    else
        if [[ "$DRY_RUN" == "1" ]]; then
            log_info "[dry-run] set LINUX_OPTIONS=\"$merged\" in $SDBOOT_MANAGE_CONF"
        else
            mkdir -p "$(dirname -- "$SDBOOT_MANAGE_CONF")"
            touch "$SDBOOT_MANAGE_CONF"
            if grep -qE '^#?LINUX_OPTIONS=' "$SDBOOT_MANAGE_CONF"; then
                sed -i -E "s|^#?LINUX_OPTIONS=.*|LINUX_OPTIONS=\"${merged}\"|" "$SDBOOT_MANAGE_CONF"
            else
                printf 'LINUX_OPTIONS="%s"\n' "$merged" >> "$SDBOOT_MANAGE_CONF"
            fi
            log_ok "updated LINUX_OPTIONS in $SDBOOT_MANAGE_CONF"
        fi
    fi

    # LINUX_FALLBACK_OPTIONS is intentionally left untouched: the fallback
    # entry stays verbose, so recovery boots never rely on our splash.
    if command -v sdboot-manage >/dev/null 2>&1; then
        run "regenerating systemd-boot entries" -- sdboot-manage gen
    else
        log_warn "sdboot-manage not on PATH — entries were not regenerated; run 'sdboot-manage gen' manually."
    fi
}

# configure_bootloader — dispatches on $BOOTLOADER (set by detect_bootloader).
configure_bootloader() {
    case "$BOOTLOADER" in
        grub) configure_grub ;;
        systemd-boot-cachyos) configure_systemd_boot_cachyos ;;
        systemd-boot) configure_systemd_boot_vanilla ;;
        *) die "No supported bootloader detected (looked for GRUB and systemd-boot)." ;;
    esac
}

# restore_bootloader_backups — used by uninstall.sh; replays every backed
# up bootloader-related file from the given session backup dir, then
# regenerates config the same way install did.
restore_bootloader_config() {
    local backup_dir="$1"
    local f rel
    [[ -f "${backup_dir}/manifest.txt" ]] || { log_warn "no backup manifest at ${backup_dir}"; return 0; }

    while IFS= read -r rel; do
        [[ -z "$rel" ]] && continue
        case "$rel" in
            "$GRUB_DEFAULTS"|"$GRUB_CFG"|"$KERNEL_CMDLINE_FILE"|"$SDBOOT_MANAGE_CONF"|*/loader/entries/*.conf)
                if [[ -f "${backup_dir}${rel}" ]]; then
                    run "restoring $rel" -- cp -a -- "${backup_dir}${rel}" "$rel"
                fi
                ;;
        esac
    done < "${backup_dir}/manifest.txt"

    case "$BOOTLOADER" in
        grub) run "regenerating $GRUB_CFG" -- grub-mkconfig -o "$GRUB_CFG" ;;
        systemd-boot-cachyos)
            if command -v sdboot-manage >/dev/null 2>&1; then
                run "regenerating entries" -- sdboot-manage gen
            fi
            ;;
        *) : ;;
    esac
}
