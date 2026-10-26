#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$HOME/Pictures/Screenshots"
filepath="$HOME/Pictures/Screenshots/$(date +%Y%m%d-%H%M%S).png"

notify() {
  command -v notify-send >/dev/null 2>&1 || return 0
  notify-send -a Screenshot -i camera-photo "$@"
}

case "${1:-fullscreen}" in
  region)
    g=$(slurp -d); [ -z "$g" ] && exit 1
    grim -g "$g" "$filepath"
    notify "Screenshot saved" "$(basename "$filepath")" ;;
  window)
    g=$(mmsg get focusing-client | jq -r '"\(.x),\(.y) \(.width)x\(.height)"')
    [ -z "$g" ] && exit 1
    grim -g "$g" "$filepath"
    notify "Screenshot saved" "$(basename "$filepath")" ;;
  clipboard)
    f=$(mktemp -t screenshot-XXXXXX.png)
    grim "$f" && wl-copy < "$f"; rm -f "$f"
    notify "Screenshot copied" "Full screen is on the clipboard" ;;
  annotate)
    g=$(slurp -d); [ -z "$g" ] && exit 1
    grim -g "$g" "$filepath"
    satty -f "$filepath" ;;
  *)
    grim "$filepath"
    notify "Screenshot saved" "$(basename "$filepath")" ;;
esac
