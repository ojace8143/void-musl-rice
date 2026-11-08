#!/usr/bin/env bash
# ricelight — match your keyboards to your rice.
# fzf-driven lighting control for the ASUS TUF (sysfs WMI) and any
# OpenRGB-detectable external keyboard.
set -uo pipefail

HERE="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
# shellcheck source=lib/common.sh
. "$HERE/lib/common.sh"
# shellcheck source=lib/asus.sh
. "$HERE/lib/asus.sh"
# shellcheck source=lib/openrgb.sh
. "$HERE/lib/openrgb.sh"

FZF_BASE=(fzf --ansi --reverse --height=85% --border --color=bg:-1,spinner:#6fae86,pointer:#478061)
dim=$'\033[2m'
rst=$'\033[0m'

palette_load

# ---------------------------------------------------------------- apply

do_apply() { # $1=effect $2=hex $3=name $4=speed [quiet]
  local effect=$1 hex=$2 name=$3 speed=${4:-normal} quiet=${5:-}
  local msg="" asus_ok=1 mech_ok=1

  if asus_apply "$effect" "$hex" "$speed"; then asus_ok=0; fi
  orgb_apply "$effect" "$hex" "$speed" && mech_ok=0

  local -a parts=()
  [[ $asus_ok -eq 0 ]] && parts+=("laptop ok") ||
    parts+=("laptop FAILED (need install.sh?)")
  if [[ $mech_ok -eq 0 ]]; then parts+=("mech ok")
  elif orgb_present; then parts+=("mech not detected")
  else parts+=("mech skipped (no openrgb)")
  fi
  msg="${parts[*]}"

  if [[ $effect != brightness ]]; then
    state_save "$effect" "$hex" "$name"
  fi

  if [[ -z $quiet ]]; then
    notify "ricelight: ${effect} ${name:+#${hex} (${name})}" "$msg"
    printf 'applied: %s %s #%s — %s\n' "$effect" "$name" "$hex" "$msg"
  fi
}

# ---------------------------------------------------------------- menus

menu_effect() {
  local g
  g=$(swatch "${PALETTE[accent]:-478061}")
  {
    printf 'static\t%s  Static          %ssolid color from your rice%s\n'      "$g" "$dim" "$rst"
    printf 'breathe\t%s  Breathe         %sslow pulse of your color%s\n'       "$g" "$dim" "$rst"
    printf 'strobe\t%s  Strobe          %sflash your color%s\n'                "$g" "$dim" "$rst"
    printf 'cycle\t  Color cycle     %shardware cycles through hues%s\n'       "$dim" "$rst"
    printf 'brightness\t  Brightness      %slaptop backlight level%s\n'        "$dim" "$rst"
    if state_load; then
      printf 'reapply\t  Re-apply last   %s%s%s\n' "$dim" "$(state_desc)" "$rst"
    fi
    printf 'off\t  Off             %skill all keyboard lights%s\n'             "$dim" "$rst"
  } | "${FZF_BASE[@]}" --prompt='effect> ' --delimiter='\t' --with-nth=2 \
      --header='ricelight — void-dark' | cut -f1
}

menu_color() { # echoes "<hex>\t<name>"
  local name hex
  for name in "${PALETTE_ORDER[@]}"; do
    hex=${PALETTE[$name]}
    printf '%s\t%s\t%s  %-16s %s#%s%s\n' "$hex" "$name" "$(swatch "$hex")" \
      "$name" "$dim" "$hex" "$rst"
  done | fzf --ansi --reverse --height=85% --border --prompt='color> ' \
      --delimiter='\t' --with-nth=3 --header='from foot.ini [colors-dark]' \
      | cut -f1,2
}

menu_brightness() { # echoes level
  local max cur n label
  max=$(asus_max_brightness); cur=$(asus_cur_brightness)
  for ((n = 0; n <= max; n++)); do
    case $n in 0) label="off";; 1) label="low";; 2) label="medium";; 3) label="high";; *) label="level $n";; esac
    printf '%s\t%s%s%s%s\n' "$n" "$([[ $n == "$cur" ]] && echo '* ')" "$label" \
      "$dim" " ($n/$max)$rst"
  done | fzf --ansi --reverse --border --prompt='brightness> ' \
      --delimiter='\t' --with-nth=2 --header='laptop backlight' | cut -f1
}

# ---------------------------------------------------------------- commands

cmd_tui() {
  local effect hex name lvl
  effect=$(menu_effect) || exit 0
  [[ -n $effect ]] || exit 0
  case $effect in
    static|breathe|strobe)
      local sel; sel=$(menu_color) || exit 0
      [[ -n $sel ]] || exit 0
      IFS=$'\t' read -r hex name <<< "$sel"
      [[ $hex =~ ^[0-9a-f]{6}$ ]] || exit 0
      do_apply "$effect" "$hex" "$name" normal
      ;;
    cycle)
      do_apply "$effect" "${PALETTE[accent]:-478061}" "" normal
      ;;
    brightness)
      lvl=$(menu_brightness) || exit 0
      asus_set_brightness "$lvl"
      notify "ricelight: brightness" "$lvl/$(asus_max_brightness)"
      ;;
    reapply)
      cmd_apply_last
      ;;
    off)
      do_apply off 000000 "" normal
      ;;
  esac
}

cmd_apply_last() {
  if state_load; then
    do_apply "$ST_EFFECT" "$ST_HEX" "$ST_NAME" normal quiet
  fi
}

cmd_status() {
  echo "== ricelight status"
  echo "state file:    $STATE_FILE ($(state_desc))"
  echo "foot.ini:      $FOOT_INI ($([[ -r $FOOT_INI ]] && echo readable || echo MISSING))"
  echo "palette:       ${#PALETTE_ORDER[@]} colors loaded"
  if asus_has_led; then
    echo "laptop LED:    present (brightness $(asus_cur_brightness)/$(asus_max_brightness))"
    if asus_rgb_writable; then echo "  kbd_rgb_mode: writable"; else
      echo "  kbd_rgb_mode: NOT writable — run: sudo $HERE/install.sh"; fi
  else
    echo "laptop LED:    not found"
  fi
  if orgb_present; then
    echo "openrgb:       installed, devices:"
    orgb_devices | while IFS=$'\t' read -r idx n m; do
      echo "  [$idx] $n"
      [[ -n $m ]] && echo "      modes: $m"
    done
    [[ $(orgb_count) -eq 0 ]] && echo "  (none detected)"
  else
    echo "openrgb:       not installed (mech keyboard control disabled)"
  fi
}

# Lab mode: walk through WMI mode numbers so we can see what this
# firmware actually supports. Requires writable kbd_rgb_mode.
cmd_lab() {
  asus_rgb_writable || { echo "kbd_rgb_mode not writable — run: sudo $HERE/install.sh"; exit 1; }
  local hex=${1:-${PALETTE[accent]:-478061}} r g b m
  read -r r g b <<< "$(hex_rgb "$hex")"
  echo "Testing WMI modes with color #$hex. Watch the keyboard, press Enter to advance, Ctrl-C to stop."
  for m in 0 1 2 10; do
    echo "0 0 1 0 0" > "$ASUS_LED/kbd_rgb_state" 2>/dev/null || true
    printf 'mode %-2s > ' "$m"
    echo "0 $m $r $g $b 1" > "$ASUS_LED/kbd_rgb_mode"
    read -r _
  done
  echo "done — tell me which numbers did what."
}

usage() {
  cat <<EOF
ricelight — match your keyboards to your rice

usage:
  ricelight                 open the fzf menu
  ricelight --apply-last    silently re-apply saved state (for autostart)
  ricelight --status        show devices and saved state
  ricelight --lab [hex]     step through laptop WMI modes (hardware testing)
  ricelight --save-bios     persist saved state to BIOS (survives boot)
EOF
}

case ${1:-} in
  "")             cmd_tui ;;
  --apply-last)   cmd_apply_last ;;
  --status)       cmd_status ;;
  --lab)          shift; cmd_lab "${1:-}" ;;
  --save-bios)
    state_load || { echo "no saved state"; exit 1; }
    if asus_apply "$ST_EFFECT" "$ST_HEX" normal 1; then
      orgb_apply "$ST_EFFECT" "$ST_HEX" normal || true
      echo "saved to BIOS: $ST_EFFECT #$ST_HEX (${ST_NAME:-n/a})"
    else
      echo "failed to write kbd_rgb_mode — run: sudo $HERE/install.sh" >&2
      exit 1
    fi
    ;;
  -h|--help)      usage ;;
  *)              usage; exit 2 ;;
esac
