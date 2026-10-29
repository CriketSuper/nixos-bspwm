#!/usr/bin/env sh
# xorgxrdp replaces XKB settings when a client connects/reconnects.
set -eu

repair_layout() {
  current=$(setxkbmap -query 2>/dev/null) || return 1
  layout=$(printf '%s\n' "$current" | awk '$1 == "layout:" {print $2}')
  options=$(printf '%s\n' "$current" | awk '$1 == "options:" {print $2}')
  case "$layout:$options" in
    us,ru:*grp:alt_shift_toggle*) return 0 ;;
  esac
  setxkbmap -rules evdev -model pc105 -layout us,ru -option grp:alt_shift_toggle
}

case "${1:---once}" in
  --once) repair_layout ;;
  --watch)
    # One guard per X display. Do not reset the selected group while the map
    # is already correct: that would interrupt Russian typing every interval.
    display_id=$(printf '%s' "${DISPLAY:?DISPLAY is required}" | tr -c 'A-Za-z0-9' '_')
    exec 9>"${XDG_RUNTIME_DIR:-/tmp}/bspwm-keyboard-$display_id.lock"
    flock -n 9 || exit 0
    trap 'exit 0' INT TERM
    while repair_layout; do sleep 2; done
    ;;
  *) printf 'Usage: keyboard-layout.sh [--once|--watch]\n' >&2; exit 2 ;;
esac
