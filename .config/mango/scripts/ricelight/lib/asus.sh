#!/usr/bin/env bash
# asus.sh — ASUS TUF WMI keyboard RGB via sysfs (kernel >= 6.13, asus-wmi)
#
# /sys/class/leds/asus::kbd_backlight/kbd_rgb_mode
#   write format: <cmd> <mode> <red> <green> <blue> <speed>
#   cmd:   0 = apply for this boot only, 1 = save to BIOS (flash)
#   mode:  0 static, 1 breathe, 2 color cycle, 10 strobe (FA507XV-verified;
#          modes 2-8 all cycle, 10/11 both strobe, 4+ has no rainbow effect)
#   speed: 0 slow, 1 normal, 2 fast
#
# /sys/class/leds/asus::kbd_backlight/kbd_rgb_state
#   write format: <cmd> <boot> <awake> <sleep> <shutdown>  (1 = lights on in that state)

ASUS_LED=/sys/class/leds/asus::kbd_backlight

asus_has_led()     { [[ -d $ASUS_LED ]]; }
asus_rgb_writable() { [[ -w $ASUS_LED/kbd_rgb_mode ]]; }
asus_brightness_writable() { [[ -w $ASUS_LED/brightness ]]; }

asus_mode_num() {
  # Empirically verified on the FA507XV firmware:
  #   0 static, 1 breathe (fade), 2 color cycle (modes 2-8 all cycle),
  #   10/11 strobe. No per-firmware rainbow mode exists.
  case ${1:-static} in
    static)  echo 0 ;;
    breathe) echo 1 ;;
    cycle)   echo 2 ;;
    strobe)  echo 10 ;;
    *)       echo 0 ;;
  esac
}

asus_speed_num() {
  case ${1:-normal} in
    slow)   echo 0 ;;
    fast)   echo 2 ;;
    *)      echo 1 ;;
  esac
}

# If brightness is 0 the RGB write shows nothing; bump to a sane level.
asus_ensure_brightness() {
  local cur
  cur=$(cat "$ASUS_LED/brightness" 2>/dev/null) || return 0
  if [[ ${cur:-0} -eq 0 ]]; then
    echo 2 > "$ASUS_LED/brightness" 2>/dev/null ||
      brightnessctl -d 'asus::kbd_backlight' set 2 >/dev/null 2>&1 || true
  fi
}

asus_set_brightness() { # $1 = 0..max
  echo "$1" > "$ASUS_LED/brightness" 2>/dev/null ||
    brightnessctl -d 'asus::kbd_backlight' set "$1" >/dev/null 2>&1
}

# asus_apply <effect> <hex> [speed] [cmd]
asus_apply() {
  local effect=${1:-static} hex=${2:-478061} speed cmd=${4:-0}
  speed=$(asus_speed_num "${3:-normal}")

  if [[ $effect == off ]]; then
    asus_set_brightness 0 && return 0 || return 1
  fi

  asus_rgb_writable || return 1
  asus_ensure_brightness

  # make sure the light is on while the system is awake (this boot only)
  [[ -w $ASUS_LED/kbd_rgb_state ]] &&
    echo "0 0 1 0 0" > "$ASUS_LED/kbd_rgb_state" 2>/dev/null || true

  local r g b
  read -r r g b <<< "$(hex_rgb "$hex")"
  echo "$cmd $(asus_mode_num "$effect") $r $g $b $speed" > "$ASUS_LED/kbd_rgb_mode"
}

asus_max_brightness() {
  cat "$ASUS_LED/max_brightness" 2>/dev/null || echo 3
}

asus_cur_brightness() {
  cat "$ASUS_LED/brightness" 2>/dev/null || echo 0
}
