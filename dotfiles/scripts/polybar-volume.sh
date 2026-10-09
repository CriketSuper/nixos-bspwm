#!/usr/bin/env sh

status=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null) || {
  printf '%s\n' '󰖁 --'
  exit 0
}

if printf '%s' "$status" | grep -q MUTED; then
  printf '%s\n' '󰖁 muted'
else
  percent=$(printf '%s\n' "$status" | awk '{ printf "%.0f%%", $2 * 100 }')
  printf '󰕾 %s\n' "$percent"
fi
