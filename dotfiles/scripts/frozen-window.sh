#!/usr/bin/env bash

set -euo pipefail

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/bspwm"
state_file="$state_dir/frozen-windows.tsv"

message() {
  notify-send -t 2500 "Закреплённые окна" "$1" 2>/dev/null || true
}

focused_window() {
  bspc query -T -n focused 2>/dev/null || true
}

window_identity() {
  local node=$1
  class=$(jq -r '.client.className // empty' <<<"$node")
  instance=$(jq -r '.client.instanceName // empty' <<<"$node")
  [ -n "$class" ] || return 1
  [ -n "$instance" ] || instance="$class"
  [[ "$class" =~ ^[[:alnum:]_.-]+$ && "$instance" =~ ^[[:alnum:]_.-]+$ ]]
}

launcher_for() {
  case "${1,,}" in
    firefox) printf 'firefox' ;;
    obsidian|md.obsidian.obsidian) printf 'obsidian' ;;
    alacritty) printf 'alacritty' ;;
    thunar) printf 'thunar' ;;
    telegramdesktop|telegram-desktop) printf 'telegram' ;;
    chromium|chromium-browser) printf 'chromium' ;;
    virtualbox) printf 'virtualbox' ;;
    *) printf 'manual' ;;
  esac
}

save_without_current() {
  local output=$1
  if [ -f "$state_file" ]; then
    awk -F '\t' -v class="$class" -v instance="$instance" \
      '$1 != class || $2 != instance' "$state_file" >"$output"
  fi
}

saved_original_state() {
  [ -f "$state_file" ] || return 1
  awk -F '\t' -v class="$class" -v instance="$instance" \
    '$1 == class && $2 == instance { print $8; found=1; exit }
     END { if (!found) exit 1 }' "$state_file"
}

freeze() {
  local node window_id state original_state monitor desktop rectangle sticky launcher temporary
  local width height x y
  node=$(focused_window)
  if ! window_identity "$node"; then
    message "Выберите окно перед закреплением"
    exit 1
  fi

  window_id=$(jq -r '.id' <<<"$node")
  state=$(jq -r '.client.state' <<<"$node")
  original_state=$(saved_original_state) || original_state="$state"
  case "$original_state" in
    tiled|pseudo_tiled|floating|fullscreen) ;;
    *) original_state=tiled ;;
  esac
  monitor=$(bspc query -M -m focused --names)
  desktop=$(bspc query -D -d focused --names)
  # BSPWM keeps the old tiled rectangle in .rectangle after a window becomes
  # floating. For an already floating window, its visible geometry lives in
  # .client.floatingRectangle instead.
  if [ "$state" = floating ]; then
    read -r width height x y < <(jq -r '.client.floatingRectangle | [.width, .height, .x, .y] | @tsv' <<<"$node")
  else
    read -r width height x y < <(jq -r '.rectangle | [.width, .height, .x, .y] | @tsv' <<<"$node")
    bspc node "$window_id" -t floating
    # Keep a formerly tiled window at the same visible size and position.
    xdotool windowsize "$window_id" "$width" "$height"
    xdotool windowmove "$window_id" "$x" "$y"
  fi
  rectangle="${width}x${height}+${x}+${y}"
  sticky=$(jq -r 'if .sticky then "on" else "off" end' <<<"$node")
  launcher=$(launcher_for "$class")

  mkdir -p "$state_dir"
  chmod 700 "$state_dir"
  temporary=$(mktemp "$state_file.XXXXXX")
  save_without_current "$temporary"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$class" "$instance" "$monitor" "$desktop" "$rectangle" "$sticky" "$launcher" "$original_state" \
    >>"$temporary"
  chmod 600 "$temporary"
  mv -f "$temporary" "$state_file"

  if [ "$launcher" = manual ]; then
    message "$class: положение сохранено; после входа откройте приложение вручную"
  else
    message "$class: положение сохранено, окно откроется после входа"
  fi
}

thaw() {
  local node window_id original_state temporary
  node=$(focused_window)
  if ! window_identity "$node"; then
    message "Выберите окно перед откреплением"
    exit 1
  fi
  original_state=$(saved_original_state) || {
    message "$class: сохранённого положения нет"
    return 0
  }
  # Old seven-column entries predate original_state. They were created from
  # tiled windows, so restore that state when removing them.
  case "$original_state" in
    tiled|pseudo_tiled|floating|fullscreen) ;;
    *) original_state=tiled ;;
  esac
  window_id=$(jq -r '.id' <<<"$node")
  temporary=$(mktemp "$state_file.XXXXXX")
  save_without_current "$temporary"
  chmod 600 "$temporary"
  mv -f "$temporary" "$state_file"
  bspc node "$window_id" -t "$original_state"
  message "$class: положение удалено, режим окна восстановлен"
}

toggle() {
  local node
  node=$(focused_window)
  if ! window_identity "$node"; then
    message "Выберите окно перед закреплением"
    return 1
  fi
  if saved_original_state >/dev/null; then
    thaw
  else
    freeze
  fi
}

start_application() {
  case "$1" in
    firefox) firefox >/dev/null 2>&1 & ;;
    obsidian) obsidian >/dev/null 2>&1 & ;;
    alacritty) alacritty >/dev/null 2>&1 & ;;
    thunar) thunar >/dev/null 2>&1 & ;;
    telegram) Telegram >/dev/null 2>&1 & ;;
    chromium) chromium >/dev/null 2>&1 & ;;
    virtualbox) VirtualBox >/dev/null 2>&1 & ;;
  esac
}

restore() {
  local saved_class saved_instance saved_monitor saved_desktop saved_rectangle
  local saved_sticky saved_launcher saved_original_state target_monitor target_desktop
  local -a rule_args
  [ -f "$state_file" ] || exit 0

  while IFS=$'\t' read -r saved_class saved_instance saved_monitor \
      saved_desktop saved_rectangle saved_sticky saved_launcher saved_original_state; do
    [[ "$saved_class" =~ ^[[:alnum:]_.-]+$ ]] || continue
    [[ "$saved_instance" =~ ^[[:alnum:]_.-]+$ ]] || continue
    [[ "$saved_rectangle" =~ ^[0-9]+x[0-9]+\+-?[0-9]+\+-?[0-9]+$ ]] || continue
    [[ "$saved_sticky" == on || "$saved_sticky" == off ]] || continue

    target_monitor="$saved_monitor"
    if ! bspc query -M -m "$target_monitor" >/dev/null 2>&1; then
      target_monitor=$(bspc query -M --names | head -n 1)
    fi
    [ -n "$target_monitor" ] || continue

    target_desktop="$saved_desktop"
    if ! bspc query -D -m "$target_monitor" --names | grep -Fxq "$target_desktop"; then
      target_desktop=$(bspc query -D -m "$target_monitor" --names | head -n 1)
    fi
    [ -n "$target_desktop" ] || continue

    rule_args=("monitor=$target_monitor" "desktop=$target_desktop"
      "state=floating" "sticky=$saved_sticky")
    if [ "$target_monitor" = "$saved_monitor" ]; then
      rule_args+=("rectangle=$saved_rectangle")
    else
      rule_args+=("center=on")
    fi

    bspc rule -a "$saved_class:$saved_instance" -o "${rule_args[@]}"
    start_application "$saved_launcher"
  done <"$state_file"
}

case "${1:-}" in
  toggle) toggle ;;
  freeze) freeze ;;
  thaw) thaw ;;
  restore) restore ;;
  *) printf 'Usage: %s {toggle|freeze|thaw|restore}\n' "$0" >&2; exit 2 ;;
esac
