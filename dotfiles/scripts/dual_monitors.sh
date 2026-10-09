#!/usr/bin/env sh
set -eu
# Saved profiles take priority; new configurations extend all connected screens.
autorandr --change --default horizontal
python3 "$HOME/.config/scripts/sync-monitors.py"
