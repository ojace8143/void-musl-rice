#!/usr/bin/env bash
set -euo pipefail

if command -v pavucontrol >/dev/null 2>&1; then
  exec pavucontrol
elif command -v pulsemixer >/dev/null 2>&1; then
  exec foot -e pulsemixer
else
  exec foot -e alsamixer
fi
