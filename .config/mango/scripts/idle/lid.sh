#!/usr/bin/env bash
set -euo pipefail

# Lid switch handling: lock + internal panel off on close, panel on on open.
# Falls back to all outputs when the internal panel can't be identified.

lock_script="$HOME/.config/mango/scripts/lock/lock.sh"

internal_output() {
  wlopm 2>/dev/null | awk '$1 ~ /^eDP/ {print $1; exit}'
}

case "${1:-}" in
  fold)
    setsid -f "$lock_script"
    sleep 1
    out="$(internal_output)"
    wlopm --off "${out:-*}" 2>/dev/null || true
    ;;
  unfold)
    out="$(internal_output)"
    wlopm --on "${out:-*}" 2>/dev/null || true
    ;;
esac