#!/usr/bin/env bash
# Screen sharing toggle for Hyprland / wayvnc.
# The VNC server binds only the current Tailscale IPv4 address, so the session
# is reachable from the tailnet and nowhere else.
# Usage: toggle.sh toggle|start|stop|status
set -uo pipefail

PORT=5900
RUNTIME="${XDG_RUNTIME_DIR:-/tmp}"
PIDFILE="$RUNTIME/screenshare.pid"
LOG="$RUNTIME/screenshare.log"

fail() {
    local msg="$1"
    local tail_log
    tail_log=$(tail -n 5 "$LOG" 2>/dev/null)
    notify-send -u critical "Screen sharing failed" "$msg"$'\n'"$tail_log" 2>/dev/null
    printf 'error: %s\n%s\n' "$msg" "$tail_log" >&2
    exit 1
}

# Print the Tailscale IPv4 address, or fail when Tailscale is not running.
tailscale_ip() {
    local state ip
    state=$(tailscale status --json 2>/dev/null |
        python3 -c 'import json, sys
try:
    print(json.load(sys.stdin).get("BackendState", ""))
except Exception:
    print("")' 2>/dev/null)
    [ "$state" = "Running" ] || return 1
    ip=$(tailscale ip -4 2>/dev/null | head -1)
    [ -n "$ip" ] || return 1
    printf '%s' "$ip"
}

get_output() {
    hyprctl monitors -j 2>/dev/null | python3 -c '
import json, sys
try:
    monitors = json.load(sys.stdin)
except Exception:
    sys.exit(1)
names = [m["name"] for m in monitors if m.get("focused") and not m.get("disabled")]
if not names:
    names = [m["name"] for m in monitors if not m.get("disabled")]
if names:
    print(names[0])
    sys.exit(0)
sys.exit(1)
' 2>/dev/null
}

url() {
    local ip
    ip=$(tailscale_ip) || return 1
    printf 'vnc://%s:%s' "$ip" "$PORT"
}

# Our recorded process is alive and the exact tailnet listener exists.
is_running() {
    [ -f "$PIDFILE" ] || return 1
    local pid ip
    pid=$(cat "$PIDFILE" 2>/dev/null)
    [ -n "$pid" ] || return 1
    kill -0 "$pid" 2>/dev/null || return 1
    ip=$(tailscale_ip) || return 1
    ss -ltnH "sport = :$PORT" 2>/dev/null |
        awk '{print $4}' | grep -qx "$ip:$PORT" || return 1
    return 0
}

port_busy() {
    ss -ltnH "sport = :$PORT" 2>/dev/null | grep -q .
}

start() {
    if is_running; then
        echo 1
        url
        return 0
    fi
    local ip
    if ! ip=$(tailscale_ip); then
        fail "Tailscale is not running, so the tailnet address is unavailable"
    fi
    local output
    if ! output=$(get_output); then
        fail "No active Hyprland session was found"
    fi
    if port_busy; then
        fail "port $PORT is already in use by another process"
    fi

    : > "$LOG"
    nohup wayvnc -o "$output" "$ip:$PORT" >>"$LOG" 2>&1 &
    local pid=$!
    echo "$pid" > "$PIDFILE"

    for _ in $(seq 1 50); do
        if ! kill -0 "$pid" 2>/dev/null; then
            break
        fi
        if ss -ltnH "sport = :$PORT" 2>/dev/null | awk '{print $4}' | grep -qx "$ip:$PORT"; then
            # WayVNC 0.10 fills capture buffers only after a
            # zwlr_output_power_v1 event, and Hyprland sends that event only
            # on a real DPMS change made while a client has started capture.
            # warmup.py provides that client and cycles DPMS; it is dropped
            # during the cycle, so later clients receive live frames.
            SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
            if ! timeout 20 python3 "$SCRIPT_DIR/warmup.py" "$ip" "$PORT" >>"$LOG" 2>&1; then
                printf 'warmup failed; capture may stay blank until the next display power change\n' >>"$LOG"
            fi
            local u
            u=$(url)
            notify-send "Screen sharing on" "$u" 2>/dev/null
            if command -v wl-copy >/dev/null 2>&1; then
                printf '%s' "$u" | wl-copy 2>/dev/null
            fi
            echo 1
            echo "$u"
            return 0
        fi
        sleep 0.1
    done

    kill "$pid" 2>/dev/null
    rm -f "$PIDFILE"
    fail "wayvnc did not open $ip:$PORT (output: ${output:-default})"
}

stop() {
    if [ -f "$PIDFILE" ]; then
        local pid
        pid=$(cat "$PIDFILE" 2>/dev/null)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null
            for _ in $(seq 1 50); do
                kill -0 "$pid" 2>/dev/null || break
                sleep 0.1
            done
            kill -9 "$pid" 2>/dev/null
        fi
        rm -f "$PIDFILE"
    fi
    if is_running; then
        fail "port $PORT is still listening after stop"
    fi
    notify-send "Screen sharing off" 2>/dev/null
    echo 0
}

case "${1:-toggle}" in
    start) start ;;
    stop) stop ;;
    status)
        if is_running; then
            echo 1
            url
        else
            echo 0
        fi
        ;;
    toggle)
        if is_running; then
            stop
        else
            start
        fi
        ;;
    *)
        echo "usage: $0 toggle|start|stop|status" >&2
        exit 2
        ;;
esac
