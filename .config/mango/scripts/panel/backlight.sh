#!/usr/bin/env bash
set -euo pipefail

for dev in /sys/class/backlight/*; do
  [ -r "$dev/brightness" ] || continue
  cur=$(cat "$dev/brightness")
  max=$(cat "$dev/max_brightness")
  [ "$max" -gt 0 ] || continue
  pct=$(( (cur * 100 + max / 2) / max ))
  printf '\uf185 %s%%\n' "$pct"
  exit 0
done

printf '\uf185 ?\n'
