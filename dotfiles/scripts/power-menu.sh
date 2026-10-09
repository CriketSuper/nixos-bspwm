#!/usr/bin/env sh

set -eu

choice=$(printf '%s\n' Lock Logout Suspend Reboot Shutdown | rofi -dmenu -i -p Power)

case "$choice" in
  Lock)
    "$HOME/.config/scripts/screen-lock.sh"
    ;;
  Logout)
    bspc quit
    ;;
  Suspend)
    "$HOME/.config/scripts/screen-lock.sh" &
    sleep 1
    systemctl suspend
    ;;
  Reboot)
    systemctl reboot
    ;;
  Shutdown)
    systemctl poweroff
    ;;
esac
