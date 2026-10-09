#!/usr/bin/env bash
set -euo pipefail
sync="$HOME/.config/scripts/sync-monitors.py"
choice=$(printf '%s\n' 'Расположение и разрешение (ARandR)' 'Авто: сохранённый профиль или расширение' 'Только экран ноутбука' 'Только внешние мониторы' 'Сохранить текущую схему' 'Загрузить профиль' | rofi -dmenu -i -p 'Мониторы') || exit 0
mapfile -t connected < <(xrandr --query | awk '$2 == "connected" {print $1}')
internal=''
externals=()
for output in "${connected[@]}"; do
  if [[ "$output" =~ ^(eDP|LVDS) ]]; then internal="$output"; else externals+=("$output"); fi
done
notify_error() { notify-send -u normal 'Мониторы' "$1"; }
case "$choice" in
  'Расположение и разрешение (ARandR)')
    arandr
    python3 "$sync"
    ;;
  'Авто: сохранённый профиль или расширение')
    autorandr --change --default horizontal || { notify_error 'Не удалось применить схему'; exit 1; }
    python3 "$sync"
    ;;
  'Только экран ноутбука')
    [[ -n "$internal" ]] || { notify_error 'Встроенный экран не найден'; exit 1; }
    args=(--output "$internal" --auto --primary --pos 0x0)
    for output in "${externals[@]}"; do args+=(--output "$output" --off); done
    xrandr "${args[@]}"
    python3 "$sync"
    ;;
  'Только внешние мониторы')
    ((${#externals[@]})) || { notify_error 'Сначала подключите внешний монитор'; exit 0; }
    args=()
    previous=''
    for output in "${externals[@]}"; do
      args+=(--output "$output" --auto)
      if [[ -z "$previous" ]]; then args+=(--primary --pos 0x0); else args+=(--right-of "$previous"); fi
      previous="$output"
    done
    [[ -z "$internal" ]] || args+=(--output "$internal" --off)
    if ! xrandr "${args[@]}"; then
      [[ -z "$internal" ]] || xrandr --output "$internal" --auto --primary
      notify_error 'Не удалось включить внешние мониторы; экран ноутбука возвращён'
      exit 1
    fi
    python3 "$sync"
    ;;
  'Сохранить текущую схему')
    profile=$(printf '%s\n' home-1 home-2 external-only | rofi -dmenu -p 'Имя профиля') || exit 0
    [[ "$profile" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]{0,31}$ ]] || { notify_error 'Имя: латинские буквы, цифры, дефис, подчёркивание'; exit 1; }
    profile_dir="${XDG_CONFIG_HOME:-$HOME/.config}/autorandr/$profile"
    if [[ -e "$profile_dir" ]]; then
      answer=$(printf '%s\n' 'Отмена' 'Перезаписать' | rofi -dmenu -p "$profile уже существует") || exit 0
      [[ "$answer" == 'Перезаписать' ]] || exit 0
      autorandr --save "$profile" --force
    else
      autorandr --save "$profile"
    fi
    python3 "$sync"
    notify-send 'Мониторы' "Схема $profile сохранена"
    ;;
  'Загрузить профиль')
    profile=$(autorandr --list | rofi -dmenu -p 'Профиль') || exit 0
    [[ -n "$profile" && "$profile" != -* ]] || exit 0
    autorandr --load "$profile" || { notify_error 'Мониторы профиля недоступны'; exit 1; }
    python3 "$sync"
    ;;
esac
