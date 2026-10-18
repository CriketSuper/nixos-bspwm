#!/usr/bin/env sh

set -eu

polybar-msg cmd quit >/dev/null 2>&1 || pkill -x polybar 2>/dev/null || true

attempt=0
while pgrep -x polybar >/dev/null && [ "$attempt" -lt 20 ]; do
  sleep 0.1
  attempt=$((attempt + 1))
done

config="$HOME/.config/polybar/config.ini"
log_dir="${XDG_CACHE_HOME:-$HOME/.cache}/polybar"
mkdir -p "$log_dir"

# Detect hardware on this machine; desktops without a battery/backlight omit those modules.
power_device() {
  for device in /sys/class/power_supply/*; do
    [ -r "$device/type" ] || continue
    if [ "$(cat "$device/type")" = "$1" ]; then basename "$device"; return; fi
  done
}
BAR_BATTERY=${BSPWM_BATTERY:-$(power_device Battery)}
BAR_ADAPTER=${BSPWM_ADAPTER:-$(power_device Mains)}
BAR_BACKLIGHT=${BSPWM_BACKLIGHT:-}
if [ -z "$BAR_BACKLIGHT" ]; then
  for device in /sys/class/backlight/*; do
    [ -r "$device/brightness" ] || continue
    BAR_BACKLIGHT=$(basename "$device")
    break
  done
fi
BAR_TEMPERATURE=''
for device in /sys/class/hwmon/*; do
  [ -r "$device/name" ] && [ -r "$device/temp1_input" ] || continue
  case "$(cat "$device/name")" in
    coretemp|k10temp|zenpower) BAR_TEMPERATURE="$device/temp1_input"; break ;;
  esac
done
BAR_MODULES_CENTER='memory space cpu'
[ -z "$BAR_TEMPERATURE" ] || BAR_MODULES_CENTER="temperature space $BAR_MODULES_CENTER"
BAR_MODULES_RIGHT='volume xkeyboard round-left time round-right space network-status space powermenu'
[ -z "$BAR_BACKLIGHT" ] || BAR_MODULES_RIGHT="backlight $BAR_MODULES_RIGHT"
[ -z "$BAR_BATTERY" ] || BAR_MODULES_RIGHT="battery $BAR_MODULES_RIGHT"
export BAR_BATTERY BAR_ADAPTER BAR_BACKLIGHT BAR_TEMPERATURE BAR_MODULES_CENTER BAR_MODULES_RIGHT


active=$(xrandr --listactivemonitors)
primary=$(printf '%s\n' "$active" | awk 'NR > 1 && $2 ~ /\*/ { print $NF; exit }')
if [ -z "$primary" ]; then
  primary=$(printf '%s\n' "$active" | awk 'NR == 2 { print $NF }')
fi

printf '%s\n' "$active" | awk 'NR > 1 { print $NF }' | while read -r monitor; do
  bar=top
  if [ "$monitor" = "$primary" ]; then bar=top-primary; fi
  MONITOR="$monitor" polybar --reload "$bar" -c "$config" \
    >>"$log_dir/$monitor.log" 2>&1 &
done
