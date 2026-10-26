#!/usr/bin/env bash
set -euo pipefail

sel=$(cliphist list | fuzzel --dmenu --prompt 'clip: ' --lines 15 --width 50) || exit 0
[ -n "${sel:-}" ] || exit 0
printf '%s\n' "$sel" | cliphist decode | wl-copy
command -v notify-send >/dev/null 2>&1 && notify-send -a Clipboard -t 1200 "Clipboard" "Copied selection" || true
