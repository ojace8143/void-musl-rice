#!/usr/bin/env bash
set -euo pipefail

if pgrep -x swaylock >/dev/null 2>&1; then
  exit 0
fi

wall="${SWAYLOCK_WALLPAPER:-$HOME/Pictures/wallpaper.jpg}"
runtime="${XDG_RUNTIME_DIR:-/tmp}"
bg="$runtime/swaylock-bg.png"

if [ -f "$wall" ]; then
  if command -v magick >/dev/null 2>&1; then
    if [ ! -f "$bg" ] || [ "$wall" -nt "$bg" ]; then
      magick "$wall" -resize 1280x -blur "0x${SWAYLOCK_BLUR:-14}" \
        -modulate "${SWAYLOCK_BRIGHTNESS:-65},95" "$bg" 2>/dev/null || true
    fi
    [ -f "$bg" ] && exec swaylock --image "$bg" --scaling fill
  fi
  exec swaylock --image "$wall" --scaling fill
fi
exec swaylock
