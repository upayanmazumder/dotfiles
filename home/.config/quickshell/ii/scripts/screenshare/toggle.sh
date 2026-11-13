#!/usr/bin/env bash
# Screen sharing toggle for Hyprland / wayvnc.
# Usage: toggle.sh toggle|start|stop|status
set -uo pipefail

PORT=5900
RUNTIME="${XDG_RUNTIME_DIR:-/tmp}"
PIDFILE="$RUNTIME/screenshare.pid"
LOG="$RUNTIME/screenshare.log"

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
' 2>/dev/null
}

get_ip() {
    local ip
    ip=$(ip -4 -o addr show dev ap0 scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -1)
    if [ -z "$ip" ]; then
        ip=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for (i=1; i<=NF; i++) if ($i=="src") {print $(i+1); exit}}')
    fi
    if [ -z "$ip" ]; then
        ip=$(ip -4 -o addr show scope global 2>/dev/null | awk '$2 != "tailscale0" {print $4}' | cut -d/ -f1 | head -1)
    fi
    echo "${ip:-127.0.0.1}"
}

url() {
    echo "vnc://$(get_ip):$PORT"
}

# Port listening AND our recorded process alive.
is_running() {
    ss -ltn 2>/dev/null | grep -q ":$PORT " || return 1
    [ -f "$PIDFILE" ] || return 1
    local pid
    pid=$(cat "$PIDFILE" 2>/dev/null)
    [ -n "$pid" ] || return 1
    kill -0 "$pid" 2>/dev/null || return 1
    return 0
}

port_busy() {
    ss -ltn 2>/dev/null | grep -q ":$PORT "
}

fail() {
    local msg="$1"
    local tail_log
    tail_log=$(tail -n 5 "$LOG" 2>/dev/null)
    notify-send -u critical "Screen sharing failed" "$msg"$'\n'"$tail_log" 2>/dev/null
    printf 'error: %s\n%s\n' "$msg" "$tail_log" >&2
    exit 1
}

start() {
    if is_running; then
        echo 1
        url
        return 0
    fi
    if port_busy; then
        fail "port $PORT is already in use by another process"
    fi

    local output
    output=$(get_output)
    : > "$LOG"
    if [ -n "$output" ]; then
        nohup wayvnc -o "$output" "0.0.0.0:$PORT" >>"$LOG" 2>&1 &
    else
        nohup wayvnc "0.0.0.0:$PORT" >>"$LOG" 2>&1 &
    fi
    local pid=$!
    echo "$pid" > "$PIDFILE"

    for _ in $(seq 1 50); do
        if ! kill -0 "$pid" 2>/dev/null; then
            break
        fi
        if ss -ltn 2>/dev/null | grep -q ":$PORT "; then
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
    fail "wayvnc did not open port $PORT (output: ${output:-default})"
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
