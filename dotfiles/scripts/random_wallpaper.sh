#!/usr/bin/env sh

set -eu

wallpaper_dir="$HOME/Pictures/wallpapers"
[ -d "$wallpaper_dir" ] || exit 0

wallpaper=$(find -L "$wallpaper_dir" -type f \
  \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
  | shuf -n 1)

[ -n "$wallpaper" ] || exit 0
feh --no-fehbg --bg-fill "$wallpaper"
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}"
mkdir -p "$cache_dir"
printf '%s\n' "$wallpaper" > "$cache_dir/bspwm-wallpaper"
