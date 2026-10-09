#!/usr/bin/env bash
set -euo pipefail

export LC_ALL=C
devices=$(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null || true)
default_device=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{ for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }' || true)

connected_type=$(printf '%s\n' "$devices" | awk -F: -v dev="$default_device" '$1 == dev && $3 == "connected" { print $2; exit }')
if [[ "$connected_type" != ethernet && "$connected_type" != wifi ]]; then
  connected_type=$(printf '%s\n' "$devices" | awk -F: '$2 == "ethernet" && $3 == "connected" { print "ethernet"; exit }')
fi
if [[ -z "$connected_type" ]]; then
  connected_type=$(printf '%s\n' "$devices" | awk -F: '$2 == "wifi" && $3 == "connected" { print "wifi"; exit }')
fi

# Preserve the last physical connection type so an unplugged Ethernet adapter
# gets a red Ethernet icon instead of retaining the previous successful output.
umask 077
state_file="${XDG_RUNTIME_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}}/polybar-network-type"
last_type=$(cat "$state_file" 2>/dev/null || true)
if [[ "$connected_type" == ethernet || "$connected_type" == wifi ]]; then
  if [[ "$last_type" != "$connected_type" ]]; then
    printf '%s\n' "$connected_type" >"$state_file" 2>/dev/null || true
  fi
  color='#A3BE8C'
  case "$connected_type" in
    ethernet) icon='󰈁' ;;
    wifi) icon='' ;;
  esac
else
  color='#D35F5E'
  case "$last_type" in
    ethernet) icon='󰈁' ;;
    *) icon='󰖪' ;;
  esac
fi
printf '%%{F%s}%s%%{F-}\n' "$color" "$icon"
