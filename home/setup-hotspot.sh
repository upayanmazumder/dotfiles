#!/usr/bin/env bash
set -euo pipefail

SSID="Sonder"
PASSPHRASE="CHANGE_ME_MIN_8_CHARS"
WAN_IF="wlan0"
AP_IF="ap0"

echo "==> Installing packages..."
pacman -Sy --noconfirm hostapd dnsmasq iptables

echo "==> Creating AP interface..."
iw dev "$AP_IF" >/dev/null 2>&1 || iw dev "$WAN_IF" interface add "$AP_IF" type __ap

ip link set "$AP_IF" down || true
ip addr flush dev "$AP_IF" || true
ip addr add 10.42.0.1/24 dev "$AP_IF"
ip link set "$AP_IF" up

mkdir -p /etc/hostapd

cat >/etc/hostapd/hostapd.conf <<EOF
interface=$AP_IF
driver=nl80211
ssid=$SSID
hw_mode=a
channel=149
ieee80211n=1
ieee80211ac=1
wmm_enabled=1
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
wpa_passphrase=$PASSPHRASE
EOF

cat >/etc/dnsmasq.d/hotspot.conf <<EOF
interface=$AP_IF
bind-interfaces
dhcp-range=10.42.0.10,10.42.0.200,255.255.255.0,12h
dhcp-option=3,10.42.0.1
dhcp-option=6,1.1.1.1,8.8.8.8
EOF

sed -i 's/^#*DAEMON_CONF=.*/DAEMON_CONF="\/etc\/hostapd\/hostapd.conf"/' /etc/conf.d/hostapd 2>/dev/null || true

echo "net.ipv4.ip_forward=1" >/etc/sysctl.d/99-hotspot.conf
sysctl --system >/dev/null

iptables -t nat -C POSTROUTING -o "$WAN_IF" -j MASQUERADE 2>/dev/null || \
iptables -t nat -A POSTROUTING -o "$WAN_IF" -j MASQUERADE

iptables -C FORWARD -i "$WAN_IF" -o "$AP_IF" -m state --state RELATED,ESTABLISHED -j ACCEPT 2>/dev/null || \
iptables -A FORWARD -i "$WAN_IF" -o "$AP_IF" -m state --state RELATED,ESTABLISHED -j ACCEPT

iptables -C FORWARD -i "$AP_IF" -o "$WAN_IF" -j ACCEPT 2>/dev/null || \
iptables -A FORWARD -i "$AP_IF" -o "$WAN_IF" -j ACCEPT

systemctl enable --now dnsmasq
systemctl enable --now hostapd

echo
echo "========================================"
echo "Hotspot started!"
echo "SSID     : $SSID"
echo "Password : $PASSPHRASE"
echo "Gateway  : 10.42.0.1"
echo "========================================"
