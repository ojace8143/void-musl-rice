#!/usr/bin/env bash
set -euo pipefail

# Idle handling: lock + screen off after IDLE_LOCK seconds (default 600),
# screen back on with activity. No suspend/shutdown.
# Detach the lock so swayidle keeps its timers while the lock is up.

lock_after="${IDLE_LOCK:-600}"
lock_script="$HOME/.config/mango/scripts/lock/lock.sh"

exec swayidle -w \
  timeout "$lock_after" "setsid -f \"$lock_script\"; sleep 1; wlopm --off '*' 2>/dev/null || true" \
  resume "wlopm --on '*' 2>/dev/null || true"