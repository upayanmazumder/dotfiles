#!/usr/bin/env python3
"""Open a short WayVNC session and force the power event capture waits for.

WayVNC 0.10 only fills capture buffers after it receives a
zwlr_output_power_v1 event. Hyprland emits that event only on a real DPMS
change, and WayVNC listens for it after a client starts the capture path.
This helper connects with the credentials in the WayVNC config, cycles DPMS,
then exits. WayVNC drops the helper client during the cycle and serves live
frames to every client that connects afterwards.

Usage: warmup.py <host> <port>
"""

import os
import socket
import ssl
import struct
import subprocess
import sys
import time

CONFIG = os.environ.get("WAYVNC_CONFIG") or os.path.expanduser("~/.config/wayvnc/config")
TIMEOUT = 15


def read_config(path):
    values = {}
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    return values


def recv_exact(sock, size):
    data = b""
    while len(data) < size:
        chunk = sock.recv(size - len(data))
        if not chunk:
            raise OSError("connection closed")
        data += chunk
    return data


def connect(host, port, username, password):
    raw = socket.create_connection((host, port), timeout=TIMEOUT)
    recv_exact(raw, 12)
    raw.sendall(b"RFB 003.008\n")
    count = recv_exact(raw, 1)[0]
    types = recv_exact(raw, count)
    if 19 not in types:
        raise OSError("server does not offer VeNCrypt")
    raw.sendall(bytes([19]))
    recv_exact(raw, 2)
    raw.sendall(bytes([0, 2]))
    recv_exact(raw, 1)
    subtypes = recv_exact(raw, 1)[0]
    offered = [struct.unpack(">I", recv_exact(raw, 4))[0] for _ in range(subtypes)]
    raw.sendall(struct.pack(">I", offered[0]))
    if recv_exact(raw, 1)[0] != 1:
        raise OSError("server rejected the VeNCrypt subtype")

    context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    context.check_hostname = False
    context.verify_mode = ssl.CERT_NONE
    tls = context.wrap_socket(raw, server_hostname=host)
    user = username.encode()
    secret = password.encode()
    tls.sendall(struct.pack(">II", len(user), len(secret)) + user + secret)
    if struct.unpack(">I", recv_exact(tls, 4))[0] != 0:
        raise OSError("authentication failed")
    tls.sendall(bytes([0]))
    recv_exact(tls, 4)
    recv_exact(tls, 16)
    name_length = struct.unpack(">I", recv_exact(tls, 4))[0]
    recv_exact(tls, name_length)
    return tls


def cycle_power():
    for action in ("off", "on"):
        subprocess.run(
            ["hyprctl", "dispatch", "dpms", action],
            capture_output=True,
            check=False,
        )
        time.sleep(0.4)


def main():
    if len(sys.argv) != 3:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    host, port = sys.argv[1], int(sys.argv[2])
    config = read_config(CONFIG)
    if not config.get("password"):
        print("warmup: no password in WayVNC config", file=sys.stderr)
        return 1
    try:
        session = connect(host, port, config.get("username", ""), config["password"])
    except (OSError, ssl.SSLError) as error:
        print(f"warmup: {error}", file=sys.stderr)
        return 1
    cycle_power()
    time.sleep(0.4)
    try:
        session.close()
    except OSError:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
