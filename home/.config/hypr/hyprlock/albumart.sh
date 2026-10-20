#!/usr/bin/env bash
# Return current cover art, or a transparent image when no cover is available.
cache="${XDG_CACHE_HOME:-$HOME/.cache}/hyprlock"
mkdir -p "$cache"
art="$cache/art.png"
blank="$HOME/.config/hypr/hyprlock/blank.png"
source_image="$cache/art.source"
next_art="$cache/art.next.png"
last_url="$cache/art.url"

command -v playerctl >/dev/null || { echo "$blank"; exit 0; }
player=()
if playerctl --player=spotify status >/dev/null 2>&1; then
  player=(--player=spotify)
fi

status=$(playerctl "${player[@]}" status 2>/dev/null)
url=$(playerctl "${player[@]}" metadata mpris:artUrl 2>/dev/null)
if [[ "$status" != Playing && "$status" != Paused ]] || [[ -z "$url" ]]; then
  echo "$blank"
  exit 0
fi

if [[ -s "$art" && -f "$last_url" && "$(<"$last_url")" == "$url" ]]; then
  echo "$art"
  exit 0
fi

case "$url" in
  file://*) cp -f "${url#file://}" "$source_image" 2>/dev/null || { echo "$blank"; exit 0; } ;;
  https://i.scdn.co/image/*) curl -fsSL -m 3 "$url" -o "$source_image" 2>/dev/null || { echo "$blank"; exit 0; } ;;
  *) echo "$blank"; exit 0 ;;
esac

if [[ -s "$source_image" ]] &&
   magick "$source_image" -resize 128x128^ -gravity center -extent 128x128 "$next_art" 2>/dev/null; then
  mv -f "$next_art" "$art"
  printf '%s' "$url" >"$last_url"
  echo "$art"
else
  echo "$blank"
fi
