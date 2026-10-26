#!/usr/bin/env bash
set -euo pipefail

lock_script="$HOME/.config/mango/scripts/lock/lock.sh"

notify() {
  command -v notify-send >/dev/null 2>&1 || return 0
  notify-send -a Power -t 1500 "$@"
}

have_polkit_agent() {
  pgrep -f 'polkit.*agent' >/dev/null 2>&1
}

run_root() {
  if command -v pkexec >/dev/null 2>&1 && have_polkit_agent; then
    pkexec "$@"
  else
    # No logind/elogind -> no GUI polkit agent. Ask for sudo in a terminal.
    foot -e sh -c "sudo $*"
  fi
}

if [ "${1:-}" = "--print" ]; then
  printf '%s\n' lock logout suspend reboot shutdown
  exit 0
fi

choice=$(printf '%s\n' lock logout suspend reboot shutdown |
  fuzzel --dmenu --prompt 'power: ' --lines 5 --width 24) || exit 0
[ -n "${choice:-}" ] || exit 0

case "$choice" in
  lock)
    exec "$lock_script"
    ;;
  logout)
    mmsg dispatch quit
    ;;
  suspend)
    if command -v pkexec >/dev/null 2>&1 && have_polkit_agent; then
      setsid -f "$lock_script"
      sleep 1
      pkexec zzz
    else
      # Lock only after resume; the screen is off while suspended.
      foot -e sh -c "sudo zzz && \"$lock_script\""
    fi
    ;;
  reboot)
    run_root reboot
    ;;
  shutdown)
    run_root poweroff
    ;;
  *)
    notify "Power" "Unknown action: $choice"
    exit 1
    ;;
esac
