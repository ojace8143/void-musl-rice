#!/usr/bin/env bash
# common.sh — palette parsing, state, notifications for ricelight
# Source of truth for colors: ~/.config/foot/foot.ini [colors-dark]

STATE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ricelight"
STATE_FILE="$STATE_DIR/state.conf"
FOOT_INI="${FOOT_INI:-$HOME/.config/foot/foot.ini}"

declare -A PALETTE=()
PALETTE_ORDER=()

# Fallback palette (void-dark) in case foot.ini is missing/unreadable
_palette_fallback() {
  local -A fb=(
    [accent]=478061 [red]=c46a6a [green]=478061 [yellow]=d8b26b
    [blue]=6f9fd1 [magenta]=b184c9 [cyan]=68b0a8 [white]=c9d1cf
    [black]=1b1f23 [foreground]=c9d1cf
    [bright-red]=d98a8a [bright-green]=6fae86 [bright-yellow]=e6c88a
    [bright-blue]=8fb8e0 [bright-magenta]=c79ed6 [bright-cyan]=84c6bf
    [bright-white]=f0f4f2 [bright-black]=505a63
  )
  local order=(accent red green yellow blue magenta cyan foreground white black
    bright-red bright-green bright-yellow bright-blue bright-magenta bright-cyan
    bright-white bright-black)
  local n
  for n in "${order[@]}"; do
    PALETTE[$n]=${fb[$n]}
    PALETTE_ORDER+=("$n")
  done
}

# Parse one section of foot.ini. $1 = section name ("colors-dark" or "colors")
_palette_parse_section() {
  local want=$1 sect="" line key val name
  local -A NAMES=(
    [selection-background]=accent
    [foreground]=foreground
    [regular0]=black [regular1]=red [regular2]=green [regular3]=yellow
    [regular4]=blue [regular5]=magenta [regular6]=cyan [regular7]=white
    [bright0]=bright-black [bright1]=bright-red [bright2]=bright-green
    [bright3]=bright-yellow [bright4]=bright-blue [bright5]=bright-magenta
    [bright6]=bright-cyan [bright7]=bright-white
  )
  local ORDER=(accent red green yellow blue magenta cyan foreground white black
    bright-red bright-green bright-yellow bright-blue bright-magenta bright-cyan
    bright-white bright-black)
  local -A FOUND=()
  while IFS= read -r line || [[ -n $line ]]; do
    line="${line%%#*}"
    if [[ $line =~ ^\ *\[([A-Za-z0-9_-]+)\] ]]; then
      sect=${BASH_REMATCH[1]}
      continue
    fi
    [[ $sect == "$want" ]] || continue
    [[ $line == *=* ]] || continue
    key="${line%%=*}"
    val="${line#*=}"
    # trim whitespace, keep only first token (cursor= has two values)
    key="$(echo "$key" | tr -d '[:space:]')"
    val="$(echo "$val" | awk '{print $1}')"
    [[ $val =~ ^[0-9a-fA-F]{6}$ ]] || continue
    name="${NAMES[$key]:-}"
    [[ -n $name ]] || continue
    [[ -n ${FOUND[$name]:-} ]] && continue
    FOUND[$name]="${val,,}"
  done < "$FOOT_INI"
  local n got=0
  for n in "${ORDER[@]}"; do
    if [[ -n ${FOUND[$n]:-} ]]; then
      PALETTE[$n]=${FOUND[$n]}
      PALETTE_ORDER+=("$n")
      got=1
    fi
  done
  return $(( got == 0 ))
}

palette_load() {
  PALETTE=(); PALETTE_ORDER=()
  if [[ -r $FOOT_INI ]]; then
    _palette_parse_section colors-dark || {
      PALETTE=(); PALETTE_ORDER=()
      _palette_parse_section colors || true
    }
  fi
  [[ ${#PALETTE_ORDER[@]} -gt 0 ]] || _palette_fallback
}

hex_rgb() { # $1=rrggbb -> "R G B"
  printf '%d %d %d' "0x${1:0:2}" "0x${1:2:2}" "0x${1:4:2}"
}

swatch() { # $1=rrggbb -> ANSI truecolor block
  local rgb; rgb=$(hex_rgb "$1")
  printf '\033[38;2;%sm███\033[0m' "${rgb// /;}"
}

notify() { # $1=title $2=body
  command -v notify-send >/dev/null 2>&1 &&
    notify-send -a ricelight -t 1800 "$1" "$2" || true
}

state_save() { # $1=effect $2=hex $3=name
  mkdir -p "$STATE_DIR"
  {
    printf 'EFFECT=%s\n' "$1"
    printf 'HEX=%s\n' "$2"
    printf 'NAME=%s\n' "$3"
  } > "$STATE_FILE"
}

state_load() { # sets ST_EFFECT ST_HEX ST_NAME; returns 1 if no state
  [[ -r $STATE_FILE ]] || return 1
  ST_EFFECT=""; ST_HEX=""; ST_NAME=""
  local line
  while IFS= read -r line; do
    case $line in
      EFFECT=*) ST_EFFECT=${line#EFFECT=} ;;
      HEX=*)    ST_HEX=${line#HEX=} ;;
      NAME=*)   ST_NAME=${line#NAME=} ;;
    esac
  done < "$STATE_FILE"
  [[ -n $ST_EFFECT && -n $ST_HEX ]]
}

state_desc() {
  state_load && printf '%s %s (#%s)' "$ST_EFFECT" "$ST_NAME" "$ST_HEX" || printf 'none'
}
