#!/usr/bin/env bash
# packettracer-fix-scaling.sh
#
# WHY THIS EXISTS
# ----------------
# Cisco Packet Tracer's AppImage bundles a Qt6 that ships only
# platforms/libqxcb.so -- there is no libqwayland-generic.so -- so it can
# never run natively on Wayland and always lands on XWayland. This machine
# sets xwayland:force_zero_scaling = true, meaning XWayland clients get the
# raw 2880x1800 surface with no compositor upscaling and are expected to
# scale themselves. Packet Tracer ignores Xft.dpi (correctly 144), so it
# draws at 1x: crisp, and about two-thirds the size it should be.
#
# The cure is QT_SCALE_FACTOR in its launcher Exec= line. The problem is
# that the launcher entries are not ours: the AppImage's own
# `pt-manage.sh activate` regenerates
# ~/.local/share/applications/CiscoPacketTracer{,Ptsa}-<ver>.desktop from a
# template whenever its signature check fails -- i.e. on every version bump
# or AppImage reinstall -- silently wiping the fix. Worse, a version bump
# changes the *filenames*, so simply tracking the 9.0.1 files in the sonder
# repo cannot fix 9.0.2.
#
# WHAT THIS DOES
# --------------
# Idempotently prefixes `env QT_SCALE_FACTOR=<scale>` onto the Exec= line of
# every CiscoPacketTracer*.desktop in the user applications dir, whatever
# the version in the filename, then refreshes the desktop database. Driven
# by packettracer-scaling.path, which watches that directory -- so a
# regenerated or newly-versioned entry is re-patched within seconds of
# appearing, with no manual step.
#
# Safe to run by hand any time; it is a no-op once every entry is patched.
#
# GOTCHAS:
#  1. Do NOT rename the desktop files to dodge regeneration. The generated
#     names own the .pkt/.pka/.pkz/.pks/.pksz MIME and pttp:// scheme
#     associations, and a differently-named copy in the same directory
#     cannot override a same-ID entry.
#  2. Do NOT set QT_SCALE_FACTOR globally instead. Nearly every other Qt
#     app here is native Wayland and already receives scale 1.5 from the
#     compositor; a global factor would scale those twice (2.25x).
#  3. A systemd --user unit has no Hyprland environment by default, so the
#     hyprctl probe below is best-effort and falls back to FALLBACK_SCALE.

set -uo pipefail

APPDIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
FALLBACK_SCALE=1.5

log() { printf '%s packettracer-fix-scaling: %s\n' "$(date '+%F %T')" "$*"; }

# eDP-1's compositor scale is the right factor: it is exactly what every
# native-Wayland client already renders at. Best-effort, because see gotcha 3.
detect_scale() {
  local s
  if command -v hyprctl >/dev/null 2>&1; then
    s=$(hyprctl monitors -j 2>/dev/null | jq -r 'map(select(.focused)) + . | .[0].scale // empty' 2>/dev/null)
    # Reject anything that is not a plain positive decimal.
    if [[ $s =~ ^[0-9]+(\.[0-9]+)?$ ]] && [[ $s != 0 ]]; then
      printf '%s' "$s"
      return
    fi
  fi
  printf '%s' "$FALLBACK_SCALE"
}

shopt -s nullglob
entries=("$APPDIR"/CiscoPacketTracer*.desktop)
if (( ${#entries[@]} == 0 )); then
  log "no CiscoPacketTracer*.desktop in $APPDIR -- nothing to do"
  exit 0
fi

scale=$(detect_scale)
patched=0

for f in "${entries[@]}"; do
  if grep -q '^Exec=.*QT_SCALE_FACTOR' "$f"; then
    continue
  fi
  if ! grep -q '^Exec=' "$f"; then
    log "WARNING: $(basename "$f") has no Exec= line, skipping"
    continue
  fi
  # Insert our env prefix directly after `Exec=`, preserving the rest of the
  # line verbatim (the %f / -uri=%u field codes matter).
  sed -i "s|^Exec=|Exec=env QT_SCALE_FACTOR=${scale} |" "$f"
  log "patched $(basename "$f") with QT_SCALE_FACTOR=${scale}"
  patched=$((patched + 1))
done

if (( patched > 0 )) && command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "$APPDIR" 2>/dev/null || true
fi

exit 0
