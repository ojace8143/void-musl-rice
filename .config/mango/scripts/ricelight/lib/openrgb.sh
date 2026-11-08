#!/usr/bin/env bash
# openrgb.sh — external mechanical keyboard (Redragon etc.) via OpenRGB CLI.
# Everything degrades gracefully when openrgb is missing or detects nothing.

orgb_present() { command -v openrgb >/dev/null 2>&1; }

# Prints one line per detected device: <idx>\t<name>\t<mode1, mode2, ...>
# Skips ASUS/TUF entries (the laptop is driven through sysfs instead).
orgb_devices() {
  orgb_present || return 0
  openrgb --list-devices 2>/dev/null | awk '
    function flush() {
      if (idx != "" && tolower(name) !~ /asus|tuf|aura/)
        printf "%s\t%s\t%s\n", idx, name, modes
    }
    {
      if (match($0, /^[[:space:]]*(Device[[:space:]]+)?[0-9]+:/)) {
        flush()
        hdr = substr($0, RSTART, RLENGTH)
        gsub(/[^0-9]/, "", hdr)
        idx = hdr
        name = substr($0, RSTART + RLENGTH)
        sub(/^[[:space:]]+/, "", name)
        modes = ""
        next
      }
      if (idx != "" && $1 == "Modes:") {
        modes = substr($0, index($0, ":") + 1)
        sub(/^[[:space:]]+/, "", modes)
        sub(/[[:space:]]+$/, "", modes)
      }
    }
    END { flush() }
  '
}

# orgb_pick_mode <modes-csv> <effect> -> best matching mode name (or "")
orgb_pick_mode() {
  local modes=$1 effect=$2 pat="" pick
  modes="${modes//,/
}"
  case $effect in
    static)  pat='^static$|^direct$|static' ;;
    breathe) pat='breath|pulse' ;;
    strobe)  pat='strobe|flash' ;;
    cycle)   pat='cycle|spectrum|rainbow|wave|marquee' ;;
    rainbow) pat='rainbow|wave|spectrum|cycle' ;;
    off)     pat='^off$|^black$' ;;
    *)       pat='static' ;;
  esac
  pick=$(echo "$modes" | grep -im1 -E "$pat" 2>/dev/null) || true
  [[ -n $pick ]] && { echo "$pick"; return 0; }
  echo "$modes" | head -1
}

# orgb_apply <effect> <hex> [speed]  — applies to every detected non-ASUS device.
# Returns 0 if at least one device was set, 1 if none.
orgb_apply() {
  local effect=${1:-static} hex=${2:-478061} idx name modes mode set=0
  while IFS=$'\t' read -r idx name modes; do
    [[ -n $idx ]] || continue
    mode=$(orgb_pick_mode "$modes" "$effect")
    if [[ $effect == off && ! $mode =~ ^[Oo]ff$ && ! $mode =~ ^[Bb]lack$ ]]; then
      mode=$(orgb_pick_mode "$modes" static)
      hex=000000
    fi
    if [[ -n $mode ]]; then
      openrgb --device "$idx" --mode "$mode" --color "$hex" >/dev/null 2>&1 && set=1
    fi
  done < <(orgb_devices)
  [[ $set -eq 1 ]]
}

orgb_count() { orgb_devices | grep -c . || true; }
