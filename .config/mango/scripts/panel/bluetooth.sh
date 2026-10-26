#!/usr/bin/env bash
set -euo pipefail

if command -v bluetui >/dev/null 2>&1; then
  exec foot -e bluetui
elif command -v bluetuith >/dev/null 2>&1; then
  exec foot -e bluetuith
else
  exec foot -e bluetoothctl
fi
