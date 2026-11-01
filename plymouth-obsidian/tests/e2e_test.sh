#!/usr/bin/env bash
# e2e_test.sh — full end-to-end run of bin/install.sh and bin/uninstall.sh
# as real programs (argument parsing, require_root, the whole main()), each
# inside a bubblewrap sandbox with /etc, /boot, /var and the plymouth theme
# directory redirected to a disposable scratch tree. Stub binaries on PATH
# stand in for pacman/mkinitcpio/grub-mkconfig/etc. so no real package
# installs or kernel builds happen.
#
# Usage: ./tests/e2e_test.sh
set -uo pipefail

SELF_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SELF_DIR}/.." && pwd)"
STUBS="${SELF_DIR}/stubs"

command -v bwrap >/dev/null 2>&1 || { echo "bwrap not available — skipping e2e tests"; exit 0; }

PASS=0
FAIL=0
assert() {
    local desc="$1" cond="$2"
    if [[ "$cond" == "1" ]]; then
        PASS=$((PASS + 1)); printf 'ok   %s\n' "$desc"
    else
        FAIL=$((FAIL + 1)); printf 'FAIL %s\n' "$desc"
    fi
}

# in_sandbox <scratch-root> <argv...> — runs argv as uid 0 with $scratch's
# etc/boot/var/usr-share-plymouth-themes overlaid on the real filesystem.
in_sandbox() {
    local scratch="$1"; shift
    mkdir -p "$scratch"/{etc,boot,var,usr/share/plymouth/themes}
    bwrap --unshare-all --uid 0 --gid 0 --die-with-parent \
        --bind / / \
        --bind "$scratch/etc" /etc \
        --bind "$scratch/boot" /boot \
        --bind "$scratch/var" /var \
        --bind "$scratch/usr/share/plymouth/themes" /usr/share/plymouth/themes \
        --proc /proc --dev /dev \
        --setenv PATH "${STUBS_OVERRIDE:-$STUBS}:/usr/bin:/bin:/usr/sbin:/sbin" \
        --setenv STUB_STATE_DIR "$scratch/var" \
        --setenv STUB_LOG "$scratch/stub.log" \
        --chdir "$ROOT_DIR" \
        -- "$@"
}

run_grub_scenario() {
    local scratch; scratch="$(mktemp -d)"
    mkdir -p "$scratch/etc/default" "$scratch/boot/grub"
    cat > "$scratch/etc/mkinitcpio.conf" <<'EOF'
HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block filesystems fsck)
EOF
    echo 'GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3"' > "$scratch/etc/default/grub"

    local out
    out="$(in_sandbox "$scratch" bash bin/install.sh --yes 2>&1)"
    assert "grub: first install exits 0" "$([[ $? -eq 0 ]] && echo 1 || echo 0)"
    echo "$out" | grep -q "All checks passed." && assert "grub: verification passed" 1 || assert "grub: verification passed" 0

    assert "grub: theme script installed" "$([[ -f "$scratch/usr/share/plymouth/themes/obsidian/obsidian.script" ]] && echo 1 || echo 0)"
    assert "grub: HOOKS contains plymouth" "$(grep -q plymouth "$scratch/etc/mkinitcpio.conf" && echo 1 || echo 0)"
    assert "grub: grub.cfg carries quiet+splash" "$(grep -q quiet "$scratch/boot/grub/grub.cfg" 2>/dev/null && grep -q splash "$scratch/boot/grub/grub.cfg" 2>/dev/null && echo 1 || echo 0)"
    assert "grub: plymouthd.conf selects obsidian" "$(grep -q '^Theme=obsidian' "$scratch/etc/plymouth/plymouthd.conf" 2>/dev/null && echo 1 || echo 0)"

    # Idempotent re-run: must succeed and must not duplicate the hook.
    local hooks_count
    in_sandbox "$scratch" bash bin/install.sh --yes >/dev/null 2>&1
    hooks_count="$(grep -o 'plymouth' "$scratch/etc/mkinitcpio.conf" | wc -l)"
    assert "grub: re-run keeps exactly one plymouth hook" "$([[ "$hooks_count" -eq 1 ]] && echo 1 || echo 0)"

    # Uninstall restores the prior theme and HOOKS line.
    in_sandbox "$scratch" bash bin/uninstall.sh --yes >/dev/null 2>&1
    assert "grub: theme directory removed" "$([[ ! -d "$scratch/usr/share/plymouth/themes/obsidian" ]] && echo 1 || echo 0)"
    assert "grub: HOOKS restored without plymouth" "$(grep -q plymouth "$scratch/etc/mkinitcpio.conf" && echo 0 || echo 1)"
    assert "grub: theme selection restored (bgrt)" "$(grep -q '^Theme=bgrt' "$scratch/etc/plymouth/plymouthd.conf" 2>/dev/null && echo 1 || echo 0)"

    echo "grub scratch: $scratch"
    [[ "${KEEP_SCRATCH:-0}" == "1" ]] || rm -rf "$scratch"
}

run_cachyos_scenario() {
    local scratch; scratch="$(mktemp -d)"
    mkdir -p "$scratch/etc" "$scratch/boot/loader/entries"
    touch "$scratch/boot/loader/loader.conf"
    cat > "$scratch/etc/mkinitcpio.conf" <<'EOF'
HOOKS=(base systemd autodetect modconf kms keyboard sd-encrypt block filesystems fsck)
EOF
    cat > "$scratch/etc/sdboot-manage.conf" <<'EOF'
#LINUX_OPTIONS=""
#LINUX_FALLBACK_OPTIONS=""
EOF
    # Pre-existing theme selection, to prove uninstall restores it.
    mkdir -p "$scratch/etc/plymouth"
    printf '[Daemon]\nTheme=bgrt\n' > "$scratch/etc/plymouth/plymouthd.conf"

    in_sandbox "$scratch" bash bin/install.sh --yes >/tmp/e2e-cachyos-install.log 2>&1
    local rc=$?
    assert "cachyos: install exits 0" "$([[ $rc -eq 0 ]] && echo 1 || echo 0)"
    assert "cachyos: HOOKS has plymouth after systemd, before sd-encrypt" \
        "$(grep -qE 'HOOKS=\(base systemd plymouth .*sd-encrypt' "$scratch/etc/mkinitcpio.conf" && echo 1 || echo 0)"
    assert "cachyos: LINUX_OPTIONS carries quiet splash" \
        "$(grep -qE '^LINUX_OPTIONS="[^"]*quiet' "$scratch/etc/sdboot-manage.conf" && echo 1 || echo 0)"
    assert "cachyos: LINUX_FALLBACK_OPTIONS untouched" \
        "$(grep -q '^#LINUX_FALLBACK_OPTIONS=""' "$scratch/etc/sdboot-manage.conf" && echo 1 || echo 0)"
    assert "cachyos: loader entry regenerated by sdboot-manage stub" \
        "$([[ -f "$scratch/boot/loader/entries/cachyos.conf" ]] && echo 1 || echo 0)"

    in_sandbox "$scratch" bash bin/uninstall.sh --yes >/tmp/e2e-cachyos-uninstall.log 2>&1
    assert "cachyos: uninstall restores prior theme (bgrt)" \
        "$(grep -q '^Theme=bgrt' "$scratch/etc/plymouth/plymouthd.conf" && echo 1 || echo 0)"
    assert "cachyos: uninstall restores LINUX_OPTIONS" \
        "$(grep -q '^#LINUX_OPTIONS=""' "$scratch/etc/sdboot-manage.conf" && echo 1 || echo 0)"

    rm -rf "$scratch"
}

run_systemd_boot_vanilla_scenario() {
    local scratch; scratch="$(mktemp -d)"
    mkdir -p "$scratch/etc" "$scratch/boot/loader/entries"
    touch "$scratch/boot/loader/loader.conf"
    cat > "$scratch/etc/mkinitcpio.conf" <<'EOF'
HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block filesystems fsck)
EOF
    cat > "$scratch/boot/loader/entries/arch.conf" <<'EOF'
title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options root=UUID=abc rw
EOF
    cat > "$scratch/boot/loader/entries/arch-fallback.conf" <<'EOF'
title Arch Linux (fallback initramfs)
linux /vmlinuz-linux
initrd /initramfs-linux-fallback.img
options root=UUID=abc rw
EOF

    STUBS_OVERRIDE="${SELF_DIR}/stubs-vanilla" in_sandbox "$scratch" env STUB_ESP_PATH=/boot bash bin/install.sh --yes >/tmp/e2e-sdboot-install.log 2>&1
    local rc=$?
    assert "sdboot: install exits 0" "$([[ $rc -eq 0 ]] && echo 1 || echo 0)"
    assert "sdboot: primary entry gains quiet splash" \
        "$(grep -q '^options.*quiet' "$scratch/boot/loader/entries/arch.conf" && echo 1 || echo 0)"
    assert "sdboot: fallback entry untouched" \
        "$(grep -q '^options root=UUID=abc rw$' "$scratch/boot/loader/entries/arch-fallback.conf" && echo 1 || echo 0)"

    STUBS_OVERRIDE="${SELF_DIR}/stubs-vanilla" in_sandbox "$scratch" env STUB_ESP_PATH=/boot bash bin/uninstall.sh --yes >/tmp/e2e-sdboot-uninstall.log 2>&1
    assert "sdboot: uninstall restores primary entry options" \
        "$(grep -q '^options root=UUID=abc rw$' "$scratch/boot/loader/entries/arch.conf" && echo 1 || echo 0)"
    assert "sdboot: theme directory removed" \
        "$([[ ! -d "$scratch/usr/share/plymouth/themes/obsidian" ]] && echo 1 || echo 0)"

    rm -rf "$scratch"
}

run_dry_run_and_purge_scenario() {
    local scratch; scratch="$(mktemp -d)"
    mkdir -p "$scratch/etc/default" "$scratch/boot/grub"
    echo 'HOOKS=(base udev autodetect modconf kms keyboard keymap consolefont block filesystems fsck)' > "$scratch/etc/mkinitcpio.conf"
    echo 'GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3"' > "$scratch/etc/default/grub"

    in_sandbox "$scratch" bash bin/install.sh --yes --dry-run >/tmp/e2e-dryrun.log 2>&1
    local rc=$?
    assert "dry-run: install exits 0" "$([[ $rc -eq 0 ]] && echo 1 || echo 0)"
    assert "dry-run: mkinitcpio.conf is untouched" \
        "$(grep -q plymouth "$scratch/etc/mkinitcpio.conf" && echo 0 || echo 1)"
    assert "dry-run: theme was not copied to disk" \
        "$([[ ! -f "$scratch/usr/share/plymouth/themes/obsidian/obsidian.script" ]] && echo 1 || echo 0)"

    # Now do a real install, then uninstall --purge and confirm exit 0 + backups gone.
    in_sandbox "$scratch" bash bin/install.sh --yes >/dev/null 2>&1
    in_sandbox "$scratch" bash bin/uninstall.sh --yes --purge >/tmp/e2e-purge.log 2>&1
    rc=$?
    assert "purge: uninstall --purge exits 0" "$([[ $rc -eq 0 ]] && echo 1 || echo 0)"
    assert "purge: backup archive removed" "$([[ ! -d "$scratch/var/backups/plymouth-obsidian" ]] && echo 1 || echo 0)"
    assert "purge: installer state removed" "$([[ ! -d "$scratch/var/lib/plymouth-obsidian" ]] && echo 1 || echo 0)"

    rm -rf "$scratch"
}

echo "== GRUB scenario =="
run_grub_scenario
echo
echo "== CachyOS systemd-boot (sdboot-manage) scenario =="
run_cachyos_scenario
echo
echo "== Vanilla Arch systemd-boot scenario =="
run_systemd_boot_vanilla_scenario
echo
echo "== --dry-run / --purge scenario =="
run_dry_run_and_purge_scenario

echo
echo "== ${PASS} passed, ${FAIL} failed =="
[[ $FAIL -eq 0 ]]
