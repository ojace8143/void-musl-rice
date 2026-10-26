#!/usr/bin/env bash
set -euo pipefail

if pgrep -x swaylock >/dev/null 2>&1; then
  exit 0
fi

wall="${SWAYLOCK_WALLPAPER:-$HOME/Pictures/wallpaper.jpg}"
runtime="${XDG_RUNTIME_DIR:-/tmp}"
blur="${SWAYLOCK_BLUR:-14}"
brightness="${SWAYLOCK_BRIGHTNESS:-65}"
bg="$runtime/swaylock-bg-${blur}-${brightness}.png"

# Avoid two lock screens if idle and lid both fire at once.
if command -v flock >/dev/null 2>&1; then
  exec 9>"$runtime/swaylock.lock"
  flock -n 9 || exit 0
fi

[ -f "$wall" ] || exec swaylock

# the blurred lock background is baked with ImageMagick (v7: magick, v6: convert)
im=
for c in magick convert; do
  if command -v "$c" >/dev/null 2>&1; then
    im=$c
    break
  fi
done

if [ -z "$im" ]; then
  printf 'lock.sh: ImageMagick not installed, locking without blur\n' >&2
  exec swaylock --image "$wall" --scaling fill
fi

if [ ! -f "$bg" ] || [ "$wall" -nt "$bg" ]; then
  "$im" "$wall" -resize 1280x -blur "0x${blur}" \
    -modulate "${brightness},95" "$bg" 2>/dev/null || true
fi

if [ -f "$bg" ]; then
  exec swaylock --image "$bg" --scaling fill
fi

printf 'lock.sh: failed to blur the wallpaper, locking without blur\n' >&2
exec swaylock --image "$wall" --scaling fill
