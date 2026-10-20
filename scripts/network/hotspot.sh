#!/usr/bin/env bash
# hotspot.sh -- on-demand wifi repeater/hotspot, sharing wlan0's current
# connection back out as an AP on the same radio.
#
# Deliberately NOT a systemd service and NOT wired to any NetworkManager
# dispatcher event. Both were tried (2026-08-26, 2026-08-29) and both
# crash-looped: the mt7921e can only run STA+AP concurrently on the same
# channel wlan0 is already associated on (`iw phy phy0 info` --
# `#{managed}+#{AP}<=1 total, #channels<=1`), and any automation that
# restarts the AP in response to wlan0 network events ends up restarting
# itself in response to its own restart. Running this by hand -- start
# when wanted, Ctrl+C or `hotspot.sh stop` when done -- sidesteps that
# entirely: nothing ever restarts without you typing a command.
#
# If wlan0 roams to a different channel while this is running, the AP
# will stop beaconing correctly -- just rerun this script.
#
# --country is required for 5GHz (mt7921e won't compute an operating
# frequency for a 5GHz channel without one, even when the regulatory
# domain already permits it -- confirmed 2026-08-29, channel 165 failed
# with "Could not determine operating frequency" until this was added).
# Read live from `iw reg get` instead of hardcoding so it stays correct
# if the machine's regdomain ever changes.
#
# -c/--freq-band are also required, on every band, not just 5GHz:
# create_ap's own log line ("wlan0 is already associated with channel
# N") is just informational -- it does NOT reliably propagate into
# hostapd's actual config (known upstream create_ap bug, references an
# unset var at that check). Left to its own default (-c defaults to 1),
# hostapd tries to beacon on a channel wlan0 isn't on and fails with
# "Failed to set beacon parameters" (confirmed 2026-08-29 on channel 11,
# 2.4GHz -- not a band-specific issue). Computed live from wlan0's
# current association, same formula the old (now-removed)
# create_ap-set-channel.sh used, just run once per invocation instead of
# on every NetworkManager event.
#
# Usage:
#   hotspot.sh          # foreground, Ctrl+C to stop
#   hotspot.sh --daemon # background
#   hotspot.sh status   # exit 0 while this interface's AP daemon is running
#   hotspot.sh stop     # stop a --daemon run
# Configure two lines (SSID, then WPA passphrase) in
# ~/.config/hotspot/credentials, owned by you and chmod 600. Never commit it.
set -euo pipefail

IFACE="wlan0"
run_create_ap() {
    if [ -t 0 ]; then
        sudo create_ap "$@"
    else
        # Quickshell starts this without a terminal; use the desktop polkit
        # agent rather than waiting for an invisible sudo password prompt.
        pkexec "$(command -v create_ap)" "$@"
    fi
}

if [ "${1:-}" = "status" ]; then
    # pgrep -f also matches parent shell/test commands that merely mention
    # "create_ap --daemon". Check argv fields of an actual create_ap process.
    for cmdline in "${HOTSPOT_PROC_ROOT:-/proc}"/[0-9]*/cmdline; do
        [ -r "$cmdline" ] || continue
        argv=()
        mapfile -d '' -t argv < "$cmdline" || continue
        [ "${#argv[@]}" -ge 2 ] || continue
        case "${argv[0]##*/}" in
            create_ap) start=1 ;;
            bash|sh|dash)
                [ "${argv[1]##*/}" = create_ap ] || continue
                start=2 ;;
            *) continue ;;
        esac
        [ "${argv[start]:-}" = "--daemon" ] || continue
        for ((i=start+1; i+1<${#argv[@]}; i++)); do
            if [ "${argv[i]}" = "$IFACE" ] && [ "${argv[i+1]}" = "$IFACE" ]; then
                exit 0
            fi
        done
    done
    exit 1
fi

if [ "${1:-}" = "stop" ]; then
    run_create_ap --stop "$IFACE"
    exit $?
fi

credentials_file="${XDG_CONFIG_HOME:-$HOME/.config}/hotspot/credentials"
if [ ! -f "$credentials_file" ] || [ -L "$credentials_file" ]; then
    printf 'Create %s with SSID on line 1 and passphrase on line 2 (chmod 600).\n' "$credentials_file" >&2
    exit 1
fi
if [ "$(stat -c %u "$credentials_file")" != "$(id -u)" ] ||
   [ -n "$(find "$credentials_file" -perm /077 -print -quit)" ]; then
    printf '%s must be owned by you and have no group/other permissions (chmod 600).\n' "$credentials_file" >&2
    exit 1
fi
mapfile -t credentials < "$credentials_file"
if [ "${#credentials[@]}" -ne 2 ] || [ -z "${credentials[0]}" ] || [ -z "${credentials[1]}" ]; then
    printf '%s must contain exactly two nonempty lines: SSID and passphrase.\n' "$credentials_file" >&2
    exit 1
fi
SSID="${credentials[0]}"
PASSPHRASE="${credentials[1]}"

args=()
[ "${1:-}" = "--daemon" ] && args+=(--daemon)

country="$(iw reg get | awk '/^country/{print substr($2,1,2); exit}')"
[ -n "$country" ] && args+=(--country "$country")

freq="$(iw dev "$IFACE" link 2>/dev/null | awk '/freq:/{print $2}')"
freq="${freq%.*}"
if [ -n "$freq" ]; then
    if [ "$freq" -lt 2484 ]; then
        channel=$(( (freq - 2407) / 5 )); band=2.4
    elif [ "$freq" -eq 2484 ]; then
        channel=14; band=2.4
    elif [ "$freq" -lt 5950 ]; then
        channel=$(( (freq - 5000) / 5 )); band=5
    else
        channel=$(( (freq - 5950) / 5 )); band=6
    fi
    args+=(-c "$channel" --freq-band "$band")
fi

run_create_ap "${args[@]}" "$IFACE" "$IFACE" "$SSID" "$PASSPHRASE"
