#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$HOME/Pictures/Screenshots"
filepath="$HOME/Pictures/Screenshots/$(date +%Y%m%d-%H%M%S).png"

case "${1:-fullscreen}" in
  region)
    g=$(slurp -d); [ -z "$g" ] && exit 1
    grim -g "$g" "$filepath" ;;
  window)
    g=$(mmsg get focusing-client | jq -r '"\(.x),\(.y) \(.width)x\(.height)"')
    [ -z "$g" ] && exit 1
    grim -g "$g" "$filepath" ;;
  clipboard)
    f=$(mktemp -t screenshot-XXXXXX.png)
    grim "$f" && wl-copy < "$f"; rm -f "$f" ;;
  *)
    grim "$filepath" ;;
esac
