#!/usr/bin/env bash
# unit_tests.sh — exercises lib/*.sh functions directly against a scratch
# directory, with every path override env var pointed there. No root and
# no bwrap sandbox required: every touched path is redirected up front.
#
# Usage: ./tests/unit_tests.sh
set -uo pipefail

SELF_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SELF_DIR}/.." && pwd)"
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT

PASS=0
FAIL=0

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        PASS=$((PASS + 1))
        printf 'ok   %s\n' "$desc"
    else
        FAIL=$((FAIL + 1))
        printf 'FAIL %s\n     expected: %q\n     actual:   %q\n' "$desc" "$expected" "$actual"
    fi
}

assert_match() {
    local desc="$1" pattern="$2" actual="$3"
    if [[ "$actual" =~ $pattern ]]; then
        PASS=$((PASS + 1))
        printf 'ok   %s\n' "$desc"
    else
        FAIL=$((FAIL + 1))
        printf 'FAIL %s\n     pattern: %s\n     actual:  %q\n' "$desc" "$pattern" "$actual"
    fi
}

# Fresh env + fresh sourcing for each scenario, so path overrides never leak.
setup_env() {
    local case_dir="$1"
    rm -rf "$case_dir"
    mkdir -p "$case_dir"/{etc/default,etc/plymouth,boot/grub,boot/loader/entries,var/lib,var/backups}
    export MKINITCPIO_CONF="${case_dir}/etc/mkinitcpio.conf"
    export GRUB_DEFAULTS="${case_dir}/etc/default/grub"
    export GRUB_CFG="${case_dir}/boot/grub/grub.cfg"
    export KERNEL_CMDLINE_FILE="${case_dir}/etc/kernel/cmdline"
    export SDBOOT_MANAGE_CONF="${case_dir}/etc/sdboot-manage.conf"
    export PLYMOUTHD_CONF="${case_dir}/etc/plymouth/plymouthd.conf"
    export THEME_DEST_DIR="${case_dir}/usr/share/plymouth/themes/obsidian"
    export BOOT_DIR="${case_dir}/boot"
    export STATE_DIR="${case_dir}/var/lib/plymouth-obsidian"
    export BACKUP_ROOT="${case_dir}/var/backups/plymouth-obsidian"
    export DRY_RUN=0 ASSUME_YES=1
}

# ---------------------------------------------------------------------
# merge_cmdline_params
# ---------------------------------------------------------------------
test_merge_cmdline_idempotent() {
    local case_dir="${SCRATCH}/merge1"; setup_env "$case_dir"
    source "${ROOT_DIR}/lib/common.sh"; source "${ROOT_DIR}/lib/bootloader.sh"

    local r1 r2
    r1="$(merge_cmdline_params "root=UUID=abc rw")"
    assert_match "merge adds all required tokens" 'quiet' "$r1"
    assert_match "merge keeps existing tokens" 'root=UUID=abc rw' "$r1"

    r2="$(merge_cmdline_params "$r1")"
    assert_eq "merge is idempotent (same input twice -> same output)" "$r1" "$r2"
}

test_merge_cmdline_respects_existing_loglevel() {
    local case_dir="${SCRATCH}/merge2"; setup_env "$case_dir"
    source "${ROOT_DIR}/lib/common.sh"; source "${ROOT_DIR}/lib/bootloader.sh"

    local r
    r="$(merge_cmdline_params "root=UUID=abc rw loglevel=7 quiet")"
    # loglevel=7 must NOT be clobbered with our loglevel=3 default.
    assert_match "existing loglevel value is preserved" 'loglevel=7' "$r"
    if [[ "$r" == *"loglevel=3"* ]]; then
        FAIL=$((FAIL + 1)); printf 'FAIL loglevel=3 must not be duplicated alongside loglevel=7\n'
    else
        PASS=$((PASS + 1)); printf 'ok   loglevel=3 not duplicated alongside existing loglevel=7\n'
    fi
    # quiet must not be duplicated either.
    local count
    count="$(grep -o 'quiet' <<< "$r" | wc -l)"
    assert_eq "'quiet' appears exactly once" "1" "$count"
}

# ---------------------------------------------------------------------
# configure_mkinitcpio_hooks
# ---------------------------------------------------------------------
test_hooks_udev_basic() {
    local case_dir="${SCRATCH}/hooks1"; setup_env "$case_dir"
    source "${ROOT_DIR}/lib/common.sh"; source "${ROOT_DIR}/lib/mkinitcpio.sh"
    init_session_backup_dir

    cat > "$MKINITCPIO_CONF" <<'EOF'
MODULES=()
BINARIES=()
FILES=()
HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block filesystems fsck)
EOF
    configure_mkinitcpio_hooks >/dev/null
    local hooks
    hooks="$(grep '^HOOKS=' "$MKINITCPIO_CONF")"
    assert_eq "plymouth inserted right after udev" \
        "HOOKS=(base udev plymouth autodetect modconf kms keyboard keymap consolefont block filesystems fsck)" \
        "$hooks"

    # Idempotency: re-run must not change anything or duplicate the hook.
    configure_mkinitcpio_hooks >/dev/null
    local hooks2
    hooks2="$(grep '^HOOKS=' "$MKINITCPIO_CONF")"
    assert_eq "second run is a no-op" "$hooks" "$hooks2"
}

test_hooks_systemd_and_encrypt() {
    local case_dir="${SCRATCH}/hooks2"; setup_env "$case_dir"
    source "${ROOT_DIR}/lib/common.sh"; source "${ROOT_DIR}/lib/mkinitcpio.sh"
    init_session_backup_dir

    cat > "$MKINITCPIO_CONF" <<'EOF'
HOOKS=(base systemd autodetect modconf kms keyboard sd-encrypt block filesystems fsck)
EOF
    configure_mkinitcpio_hooks >/dev/null
    local hooks
    hooks="$(grep '^HOOKS=' "$MKINITCPIO_CONF")"
    assert_eq "plymouth inserted after systemd, before sd-encrypt" \
        "HOOKS=(base systemd plymouth autodetect modconf kms keyboard sd-encrypt block filesystems fsck)" \
        "$hooks"
}

test_hooks_misordered_gets_fixed() {
    local case_dir="${SCRATCH}/hooks3"; setup_env "$case_dir"
    source "${ROOT_DIR}/lib/common.sh"; source "${ROOT_DIR}/lib/mkinitcpio.sh"
    init_session_backup_dir

    # plymouth present but AFTER encrypt — must be repositioned, not left alone.
    cat > "$MKINITCPIO_CONF" <<'EOF'
HOOKS=(base udev autodetect modconf kms keyboard keymap encrypt plymouth block filesystems fsck)
EOF
    configure_mkinitcpio_hooks >/dev/null
    local hooks
    hooks="$(grep '^HOOKS=' "$MKINITCPIO_CONF")"
    assert_eq "misordered plymouth (after encrypt) is corrected" \
        "HOOKS=(base udev plymouth autodetect modconf kms keyboard keymap encrypt block filesystems fsck)" \
        "$hooks"
}

test_hooks_backup_written() {
    local case_dir="${SCRATCH}/hooks4"; setup_env "$case_dir"
    source "${ROOT_DIR}/lib/common.sh"; source "${ROOT_DIR}/lib/mkinitcpio.sh"
    init_session_backup_dir

    echo 'HOOKS=(base udev autodetect filesystems fsck)' > "$MKINITCPIO_CONF"
    configure_mkinitcpio_hooks >/dev/null
    assert_eq "a backup of mkinitcpio.conf was recorded in the manifest" \
        "$MKINITCPIO_CONF" \
        "$(cat "${SESSION_BACKUP_DIR}/manifest.txt")"
    assert_match "the backup file itself was written" 'HOOKS=\(base udev autodetect filesystems fsck\)' \
        "$(cat "${SESSION_BACKUP_DIR}${MKINITCPIO_CONF}")"
}

# ---------------------------------------------------------------------
# GRUB kernel-parameter merge (function-level, stubbed grub-mkconfig)
# ---------------------------------------------------------------------
test_grub_cmdline_merge_and_rebuild() {
    local case_dir="${SCRATCH}/grub1"; setup_env "$case_dir"
    source "${ROOT_DIR}/lib/common.sh"; source "${ROOT_DIR}/lib/bootloader.sh"
    init_session_backup_dir

    echo 'GRUB_CMDLINE_LINUX_DEFAULT="loglevel=7"' > "$GRUB_DEFAULTS"
    PATH="${SELF_DIR}/stubs:${PATH}" STUB_LOG="${case_dir}/stub.log" configure_grub >/dev/null

    local val
    val="$(grep GRUB_CMDLINE_LINUX_DEFAULT "$GRUB_DEFAULTS")"
    assert_match "grub cmdline gains quiet/splash" 'quiet' "$val"
    assert_match "grub cmdline keeps loglevel=7" 'loglevel=7' "$val"
    assert_eq "grub.cfg regenerated by stub" "1" "$([[ -f "$GRUB_CFG" ]] && echo 1 || echo 0)"
}

# ---------------------------------------------------------------------
# systemd-boot vanilla: fallback entries must be left untouched
# ---------------------------------------------------------------------
test_systemd_boot_vanilla_skips_fallback() {
    local case_dir="${SCRATCH}/sdboot1"; setup_env "$case_dir"
    export STUB_ESP_PATH="${case_dir}/boot"
    source "${ROOT_DIR}/lib/common.sh"; source "${ROOT_DIR}/lib/bootloader.sh"
    init_session_backup_dir

    mkdir -p "${case_dir}/boot/loader/entries"
    cat > "${case_dir}/boot/loader/entries/arch.conf" <<'EOF'
title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options root=UUID=abc rw
EOF
    cat > "${case_dir}/boot/loader/entries/arch-fallback.conf" <<'EOF'
title Arch Linux (fallback initramfs)
linux /vmlinuz-linux
initrd /initramfs-linux-fallback.img
options root=UUID=abc rw
EOF

    PATH="${SELF_DIR}/stubs:${PATH}" configure_systemd_boot_vanilla >/dev/null

    local primary fallback
    primary="$(grep '^options' "${case_dir}/boot/loader/entries/arch.conf")"
    fallback="$(grep '^options' "${case_dir}/boot/loader/entries/arch-fallback.conf")"
    assert_match "primary entry gains quiet splash" 'quiet.*splash|splash.*quiet' "$primary"
    assert_eq "fallback entry is untouched" "options root=UUID=abc rw" "$fallback"
}

# ---------------------------------------------------------------------
# CachyOS sdboot-manage: LINUX_FALLBACK_OPTIONS must be untouched
# ---------------------------------------------------------------------
test_systemd_boot_cachyos_leaves_fallback_options() {
    local case_dir="${SCRATCH}/sdboot2"; setup_env "$case_dir"
    source "${ROOT_DIR}/lib/common.sh"; source "${ROOT_DIR}/lib/bootloader.sh"
    init_session_backup_dir

    cat > "$SDBOOT_MANAGE_CONF" <<'EOF'
LINUX_OPTIONS="loglevel=7"
LINUX_FALLBACK_OPTIONS=""
EOF
    PATH="${SELF_DIR}/stubs:${PATH}" STUB_LOG="${case_dir}/stub.log" configure_systemd_boot_cachyos >/dev/null

    local opts fallback_opts
    opts="$(grep '^LINUX_OPTIONS=' "$SDBOOT_MANAGE_CONF")"
    fallback_opts="$(grep '^LINUX_FALLBACK_OPTIONS=' "$SDBOOT_MANAGE_CONF")"
    assert_match "LINUX_OPTIONS gains quiet splash" 'quiet' "$opts"
    assert_eq "LINUX_FALLBACK_OPTIONS is untouched" 'LINUX_FALLBACK_OPTIONS=""' "$fallback_opts"
}

# ---------------------------------------------------------------------
# backup/restore round trip
# ---------------------------------------------------------------------
test_backup_restore_roundtrip() {
    local case_dir="${SCRATCH}/backup1"; setup_env "$case_dir"
    source "${ROOT_DIR}/lib/common.sh"
    init_session_backup_dir

    echo "original content" > "$GRUB_DEFAULTS"
    backup_file "$GRUB_DEFAULTS"
    echo "mutated content" > "$GRUB_DEFAULTS"

    assert_eq "backup preserved original content" "original content" "$(cat "${SESSION_BACKUP_DIR}${GRUB_DEFAULTS}")"
    cp -a "${SESSION_BACKUP_DIR}${GRUB_DEFAULTS}" "$GRUB_DEFAULTS"
    assert_eq "restore round-trips exactly" "original content" "$(cat "$GRUB_DEFAULTS")"
}

test_state_get_set() {
    local case_dir="${SCRATCH}/state1"; setup_env "$case_dir"
    source "${ROOT_DIR}/lib/common.sh"

    state_set previous_theme "bgrt"
    assert_eq "state_get returns stored value" "bgrt" "$(state_get previous_theme)"
    state_set previous_theme "spinner"
    assert_eq "state_set overwrites rather than duplicating" "spinner" "$(state_get previous_theme)"
    assert_eq "state_get default applies for missing key" "fallback" "$(state_get nonexistent_key fallback)"
}

main() {
    test_merge_cmdline_idempotent
    test_merge_cmdline_respects_existing_loglevel
    test_hooks_udev_basic
    test_hooks_systemd_and_encrypt
    test_hooks_misordered_gets_fixed
    test_hooks_backup_written
    test_grub_cmdline_merge_and_rebuild
    test_systemd_boot_vanilla_skips_fallback
    test_systemd_boot_cachyos_leaves_fallback_options
    test_backup_restore_roundtrip
    test_state_get_set

    echo
    echo "== ${PASS} passed, ${FAIL} failed =="
    [[ $FAIL -eq 0 ]]
}

main
