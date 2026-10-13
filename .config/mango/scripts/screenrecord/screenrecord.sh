#!/usr/bin/env bash
set -euo pipefail

outdir="$HOME/Videos/Recordings"
mkdir -p "$outdir"
state="${XDG_RUNTIME_DIR:-/tmp}/wf-recorder.pid"

notify() { command -v notify-send >/dev/null 2>&1 && notify-send -a "Screen Record" "$@" || true; }

is_recording() { [ -f "$state" ] && kill -0 "$(cat "$state")" 2>/dev/null; }

stop() {
  if is_recording; then
    kill -INT "$(cat "$state")" 2>/dev/null || true
    notify "Recording saved"
  fi
  rm -f "$state"
}

if is_recording; then
  stop
  exit 0
fi

mode="${1:-full}"
region=""
if [ "$mode" = "region" ]; then
  region=$(slurp -d) || exit 1
  [ -n "$region" ] || exit 1
fi

audio=()
if [ "${RECORD_AUDIO:-0}" = "1" ] && wf-recorder --help 2>&1 | grep -q -- '--audio'; then
  audio=(--audio)
fi

out="$outdir/$(date +%Y%m%d-%H%M%S).mp4"
if [ -n "$region" ]; then
  wf-recorder "${audio[@]}" -g "$region" -f "$out" &
else
  wf-recorder "${audio[@]}" -f "$out" &
fi
echo "$!" > "$state"
notify "Recording -> $(basename "$out")"
