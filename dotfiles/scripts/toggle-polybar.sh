#!/usr/bin/env sh

set -eu

if pgrep -x polybar >/dev/null; then
  polybar-msg cmd quit >/dev/null 2>&1 || pkill -x polybar
  padding=0
else
  "$HOME/.config/polybar/launch.sh"
  padding=36
fi

for monitor in $(bspc query -M --names); do
  bspc config -m "$monitor" top_padding "$padding"
done
