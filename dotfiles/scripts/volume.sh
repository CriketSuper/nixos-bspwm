#!/usr/bin/env sh

set -eu

case "${1:-}" in
  up)
    wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
    wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 2%+
    ;;
  down)
    wpctl set-mute @DEFAULT_AUDIO_SINK@ 0
    wpctl set-volume @DEFAULT_AUDIO_SINK@ 2%-
    ;;
  mute)
    wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
    ;;
  mic-mute)
    wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
    ;;
  *)
    exit 2
    ;;
esac

status=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
dunstify -a volume -u low -r 6900 -t 900 "Volume" "$status"
