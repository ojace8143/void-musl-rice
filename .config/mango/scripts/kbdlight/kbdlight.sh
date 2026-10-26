#!/usr/bin/env bash
set -euo pipefail

dev=asus::kbd_backlight
case "${1:-up}" in
  up) brightnessctl --device="$dev" set +1 ;;
  down) brightnessctl --device="$dev" set 1- ;;
  *) printf 'usage: %s up|down\n' "$0" >&2; exit 2 ;;
esac

cur=$(brightnessctl --device="$dev" get 2>/dev/null || printf '?')
max=$(brightnessctl --device="$dev" max 2>/dev/null || printf '?')
command -v notify-send >/dev/null 2>&1 &&
  notify-send -a Keyboard -t 1200 "Keyboard backlight" "${cur}/${max}" || true
