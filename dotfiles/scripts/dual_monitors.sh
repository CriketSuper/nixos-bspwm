#!/usr/bin/env sh
set -eu
# RDP controls its own virtual monitor and resolution; do not load physical EDID profiles.
if [ "${BSPWM_RDP_SESSION:-0}" != 1 ]; then
  autorandr --change --default horizontal
fi
python3 "$HOME/.config/scripts/sync-monitors.py"
