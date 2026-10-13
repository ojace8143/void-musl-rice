#!/usr/bin/env bash
set -euo pipefail

cmd=$(bash -c 'compgen -c' | sort -u | fuzzel --dmenu --prompt 'run: ' --lines 15) || exit 0
[ -n "${cmd:-}" ] || exit 0
exec bash -c "$cmd"
