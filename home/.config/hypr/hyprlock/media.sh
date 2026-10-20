#!/usr/bin/env bash
# Hyprlock's media label. No player or no title means no widget text.
command -v playerctl >/dev/null || exit 0

player=()
if playerctl --player=spotify status >/dev/null 2>&1; then
  player=(--player=spotify)
fi

status=$(playerctl "${player[@]}" status 2>/dev/null)
[[ "$status" == Playing || "$status" == Paused ]] || exit 0

title=$(playerctl "${player[@]}" metadata title 2>/dev/null)
[[ -n "$title" ]] || exit 0
artist=$(playerctl "${player[@]}" metadata artist 2>/dev/null)
source=$(playerctl "${player[@]}" metadata --format '{{playerName}}' 2>/dev/null)
[[ "$source" == spotify ]] && source=Spotify
[[ "$status" == Paused ]] && source+=" · paused"

# Keep long metadata within the small widget and escape Pango markup.
escape() {
  printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'
}
title=$(escape "${title:0:38}")
artist=$(escape "${artist:0:44}")
source=$(escape "${source:0:30}")

printf '<span foreground="#b4befe" size="small">%s</span>\n' "$source"
printf '<span foreground="#cdd6f4">%s</span>\n' "$title"
[[ -n "$artist" ]] && printf '<span foreground="#a6adc8" size="small">%s</span>\n' "$artist"
