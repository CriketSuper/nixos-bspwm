#!/usr/bin/env sh

set -eu

battery=$(find /sys/class/power_supply -maxdepth 1 -name 'BAT*' | sed -n '1p')
[ -n "$battery" ] || exit 0

last_state=normal
while sleep 60; do
  capacity=$(cat "$battery/capacity")
  status=$(cat "$battery/status")

  if [ "$status" = "Charging" ] || [ "$status" = "Full" ]; then
    last_state=normal
    continue
  fi

  if [ "$capacity" -le 10 ] && [ "$last_state" != critical ]; then
    notify-send -u critical "Battery critical" "$capacity% remaining"
    last_state=critical
  elif [ "$capacity" -le 25 ] && [ "$last_state" = normal ]; then
    notify-send -u normal "Battery low" "$capacity% remaining"
    last_state=low
  fi
done
