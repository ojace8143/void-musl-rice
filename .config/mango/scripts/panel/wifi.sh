#!/usr/bin/env bash
set -euo pipefail

if command -v impala >/dev/null 2>&1; then
  exec foot -e impala
elif command -v iwgtk >/dev/null 2>&1; then
  exec iwgtk
else
  exec foot -e iwctl
fi
