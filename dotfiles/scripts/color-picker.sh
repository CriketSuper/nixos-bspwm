#!/usr/bin/env sh

set -eu

if pgrep -f '^gpick -pso --no-newline$' >/dev/null; then
  pkill -TERM -f '^gpick -pso --no-newline$'
  exit 0
fi

color=$(gpick -pso --no-newline)
[ -n "$color" ] || exit 0
printf '%s' "$color" | xclip -selection clipboard
notify-send -a color-picker "Color copied" "$color"
