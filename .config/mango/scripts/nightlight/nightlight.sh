#!/usr/bin/env bash
set -euo pipefail

notify() {
  command -v notify-send >/dev/null 2>&1 || return 0
  notify-send -a Night\ Light -t 1500 "$@"
}

case "${1:-toggle}" in
  status) pgrep -x gammastep >/dev/null && echo on || echo off ;;
  off) pkill -x gammastep 2>/dev/null || true; notify "Night light" "Off" ;;
  on|toggle)
    if pgrep -x gammastep >/dev/null; then
      [ "${1:-toggle}" = "on" ] && exit 0
      pkill -x gammastep 2>/dev/null || true
      notify "Night light" "Off"
    else
      setsid -f gammastep -O 4000
      notify "Night light" "On (4000K)"
    fi
    ;;
  *) printf 'usage: %s on|off|toggle|status\n' "$0" >&2; exit 2 ;;
esac
