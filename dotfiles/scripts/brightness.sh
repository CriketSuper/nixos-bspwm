#!/usr/bin/env sh

set -eu

current=$(brightnessctl --class=backlight get)
maximum=$(brightnessctl --class=backlight max)
[ "$maximum" -gt 0 ] || exit 1
percent=$(( (current * 100 + maximum / 2) / maximum ))

case "${1:-}" in
  up)
    target=$(( (percent / 10 + 1) * 10 ))
    [ "$target" -le 100 ] || target=100
    ;;
  down)
    if [ $((percent % 10)) -eq 0 ]; then
      target=$((percent - 10))
    else
      target=$((percent / 10 * 10))
    fi
    [ "$target" -ge 10 ] || target=10
    ;;
  *) exit 2 ;;
esac

brightnessctl --class=backlight set "${target}%" >/dev/null
dunstify -a brightness -u low -r 6901 -t 900 "Brightness" "${target}%"
