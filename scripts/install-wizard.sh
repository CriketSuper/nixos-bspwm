#!/usr/bin/env bash
set -euo pipefail
umask 077
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
entry="$repo_dir/scripts/install-wizard.sh"
target=/etc/nixos
while [ "$#" -gt 0 ]; do
  case "$1" in
    --target) [ "$#" -ge 2 ] || { printf 'Missing target\n' >&2; exit 1; }; target=$2; shift 2 ;;
    --help|-h) printf 'Usage: ./install.sh [--wizard --target DIR]\n'; exit 0 ;;
    *) printf 'Unknown wizard option: %s\n' "$1" >&2; exit 1 ;;
  esac
done
if [ "$(id -u)" -ne 0 ]; then
  exec sudo env PATH="$PATH" bash "$entry" --target "$target"
fi
[ -e /etc/NIXOS ] || { printf 'Нужна уже установленная NixOS.\n' >&2; exit 1; }
[ "$(uname -m)" = x86_64 ] && [ -d /sys/firmware/efi ] || {
  printf 'Мастер рассчитан на x86_64 с UEFI. Другие варианты описаны в docs/installation.md.\n' >&2
  exit 1
}
[ -t 0 ] && [ -t 1 ] || { printf 'Для мастера нужен интерактивный терминал. Для SSH используйте ssh -t.\n' >&2; exit 1; }
missing=false
for command in dialog git python3; do
  command -v "$command" >/dev/null || missing=true
done
if "$missing"; then
  [ "${BSPWM_WIZARD_DEPS_ATTEMPTED:-0}" != 1 ] || { printf 'Не удалось загрузить зависимости мастера.\n' >&2; exit 1; }
  export BSPWM_WIZARD_ENTRY="$entry" BSPWM_WIZARD_TARGET="$target" BSPWM_WIZARD_DEPS_ATTEMPTED=1
  # shellcheck disable=SC2016 # Expanded by the shell inside nix-shell.
  exec nix-shell -p git python3 dialog --run 'exec bash "$BSPWM_WIZARD_ENTRY" --target "$BSPWM_WIZARD_TARGET"'
fi
ui() { dialog --backtitle 'NixOS BSPWM — мастер установки' "$@"; }
cancel() { clear; printf 'Установка отменена до запуска сборки.\n'; exit 0; }
info() { ui --title "$1" --msgbox "$2" 0 0; }
input() {
  local value
  value=$(ui --stdout --title "$1" --inputbox "$2" 0 0 "$3") || return 130
  printf '%s' "$value"
}
port_input() {
  local value
  while true; do
    value=$(input "$1" 'TCP-порт (1–65535):' "$2") || return 130
    if [[ "$value" =~ ^[0-9]{1,5}$ ]] && ((10#$value >= 1 && 10#$value <= 65535)); then printf '%s' "$((10#$value))"; return; fi
    info 'Неверный порт' 'Введите число от 1 до 65535.'
  done
}
[[ "$target" =~ ^/[a-zA-Z0-9_./-]+$ ]] || { info 'Неверный путь' 'Нужен абсолютный путь без пробелов.'; exit 1; }
target=$(realpath -m -- "$target")
[ "$target" != / ] || { info 'Неверный путь' 'Нельзя использовать корень файловой системы.'; exit 1; }
ui --title 'Установка BSPWM' --yesno 'Мастер настроит рабочий стол на уже установленной NixOS. Разделы диска не форматируются. Перед изменениями будет сохранена резервная копия конфигурации.\n\nПродолжить?' 0 0 || cancel
replace_args=()
existing=false
if [ -e "$target/flake.nix" ] || [ -e "$target/bspwm-repo" ]; then
  ui --defaultno --title 'Существующая конфигурация' --yesno 'В этой папке уже есть flake или Git-конфигурация. Обновить её?\n\nЛокальные файлы local/ сохранятся. Настройки пользователя, программ и ключей из них не перезаписываются.' 0 0 || cancel
  replace_args=(--replace)
  existing=true
fi
profile_default=universal
if [ -f "$target/flake.nix" ]; then
  previous_profile=$(sed -nE 's/^[[:space:]]*profile = "([a-z0-9-]+)";.*/\1/p' "$target/flake.nix" | head -n 1)
  case "$previous_profile" in universal|huawei-matebook-d16) profile_default=$previous_profile ;; esac
fi
profile=$(ui --stdout --default-item "$profile_default" --title 'Профиль компьютера' --menu 'Выберите аппаратный профиль:' 0 0 2 \
  universal 'Другой ПК Intel/AMD' \
  huawei-matebook-d16 'Huawei MateBook D16 AMD, BOM-WXX9') || cancel
if [ "$profile" = huawei-matebook-d16 ] && ! grep -q AuthenticAMD /proc/cpuinfo; then
  info 'Профиль не подходит' 'Для Intel MateBook и других компьютеров используйте universal.'
  exit 1
fi
username=${SUDO_USER:-}
if [ -z "$username" ] || [ "$username" = root ]; then username=$(getent passwd 1000 | cut -d : -f 1 || true); fi
hostname=$(hostname)
settings_dir=$(mktemp -d)
trap 'rm -rf -- "$settings_dir"' EXIT
args=(--profile "$profile" --target "$target")
if ! "$existing" || [ ! -f "$target/local/settings.nix" ]; then
  while true; do
    username=$(input 'Пользователь' 'Имя уже существующего обычного пользователя. Его пароль останется прежним:' "$username") || cancel
    if [[ "$username" =~ ^[a-z_][a-z0-9_-]*$ ]] && id "$username" >/dev/null 2>&1 && [ "$(id -u "$username")" -ge 1000 ]; then break; fi
    info 'Пользователь не найден' 'Создайте обычного пользователя штатными средствами NixOS или укажите существующего.'
  done
  while true; do
    hostname=$(input 'Имя компьютера' 'Hostname (латиница, цифры, дефис):' "$hostname") || cancel
    [[ "$hostname" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*$ ]] && break
    info 'Неверное имя' 'Используйте латиницу, цифры и дефис.'
  done
  timezone=$(timedatectl show -p Timezone --value 2>/dev/null || true)
  timezone=${timezone:-Asia/Yekaterinburg}
  while true; do
    timezone=$(input 'Часовой пояс' 'Например Asia/Yekaterinburg, Europe/Moscow или Etc/UTC:' "$timezone") || cancel
    if timedatectl list-timezones | grep -Fx -- "$timezone" >/dev/null; then break; fi
    info 'Часовой пояс не найден' 'Укажите название из timedatectl list-timezones.'
  done
  state_version=""
  if [ -f /etc/nixos/configuration.nix ]; then
    state_version=$(sed -nE 's/^[[:space:]]*system\.stateVersion[[:space:]]*=[[:space:]]*"([0-9]{2}\.[0-9]{2})";.*/\1/p' /etc/nixos/configuration.nix | head -n 1)
  fi
  state_version=${state_version:-$(nixos-version | cut -d . -f 1,2)}
  while true; do
    state_version=$(input 'Совместимость данных' 'system.stateVersion — исходная версия установки, не номер обновления. Для существующей системы оставьте прежнее значение:' "$state_version") || cancel
    [[ "$state_version" =~ ^[0-9]{2}\.[0-9]{2}$ ]] && break
    info 'Неверная версия' 'Ожидается формат 26.05.'
  done
  features=$(ui --stdout --separate-output --title 'Программы и службы' --checklist 'Пробел — отметить; Enter — продолжить. Основной рабочий стол и обычные приложения устанавливаются всегда.' 0 0 5 \
    development 'Редакторы, компиляторы и инструменты разработки' on \
    virtualisation 'Docker и QEMU (без VirtualBox)' on \
    vpn 'Hiddify, v2rayA/Xray, AmneziaVPN' on \
    rdp 'Удалённый рабочий стол xrdp' on \
    ssh 'SSH по вашему публичному ключу' off) || cancel
  selected() { grep -Fqx -- "$1" <<<"$features"; }
  rdp_port=3389
  ssh_port=5555
  if selected rdp; then rdp_port=$(port_input 'Порт RDP' 3389) || cancel; fi
  if selected ssh; then
    ssh_port=$(port_input 'Порт SSH' 5555) || cancel
    user_home=$(getent passwd "$username" | cut -d : -f 6)
    key_path="$user_home/.ssh/id_ed25519.pub"
    while true; do
      key_path=$(input 'Публичный SSH-ключ' 'Полный путь к файлу .pub. Закрытый ключ не нужен:' "$key_path") || cancel
      if [ -f "$key_path" ] && ! grep -q 'PRIVATE KEY' "$key_path" && ssh-keygen -lf "$key_path" >/dev/null 2>&1; then break; fi
      info 'Неверный ключ' 'Укажите существующий публичный ключ, например id_ed25519.pub.'
    done
    args+=(--ssh-key "$key_path")
  fi
  python3 - "$settings_dir/options.json" "$timezone" "$state_version" "$rdp_port" "$ssh_port" "$features" <<'PY'
import json, pathlib, sys
out, zone, state, rdp_port, ssh_port, selected = sys.argv[1:]
selected = selected.splitlines()
choices = {name: name in selected for name in ('development', 'virtualisation', 'vpn', 'rdp')}
choices.update(timezone=zone, stateVersion=state, rdpPort=int(rdp_port), sshPort=int(ssh_port))
pathlib.Path(out).write_text(json.dumps(choices))
PY
  args+=(--settings-json "$settings_dir/options.json")
  component_names=()
  selected development && component_names+=('Разработка')
  selected virtualisation && component_names+=('Docker/QEMU')
  selected vpn && component_names+=('VPN-клиенты')
  if selected rdp; then component_names+=("RDP:$rdp_port"); fi
  if selected ssh; then component_names+=("SSH:$ssh_port"); fi
  component_summary='Только базовый рабочий стол'
  if [ "${#component_names[@]}" -gt 0 ]; then
    component_summary=$(IFS=', '; printf '%s' "${component_names[*]}")
  fi
  summary="Профиль: $profile\nПользователь: $username\nКомпьютер: $hostname\nЧасовой пояс: $timezone\nstateVersion: $state_version\nКомпоненты: $component_summary\nПапка конфигурации: $target"
  if selected ssh; then summary="$summary\nПубличный SSH-ключ: $key_path"; fi
else
  summary="Профиль: $profile\nПапка конфигурации: $target\nСуществующие local/ и пароли сохраняются. Новые параметры пользователя и служб не назначаются."
fi
args+=(--user "$username" --hostname "$hostname" "${replace_args[@]}")
mode=$(ui --stdout --title 'Проверка и установка' --default-item build --menu "$summary\n\nВыберите действие:" 0 0 3 \
  build 'Собрать без переключения системы (рекомендуется)' \
  switch 'Собрать и применить конфигурацию' \
  prepare 'Только подготовить файлы') || cancel
log_dir=/var/log/nixos-bspwm
install -d -m 700 "$log_dir"
log_file="$log_dir/install-$(date +%Y%m%d-%H%M%S)-$$.log"
set +e
bash "$repo_dir/scripts/install.sh" "${args[@]}" --mode "$mode" 2>&1 | tee "$log_file" | ui --title 'Установка BSPWM' --programbox 0 0
pipeline_status=("${PIPESTATUS[@]}")
set -e
if [ "${pipeline_status[0]}" -ne 0 ]; then
  info 'Установка не завершена' "Подробности: $log_file\nРезервные копии: /var/backups/nixos-bspwm/\nЕсли сборка не удалась, новая система не активирована."
  exit 1
fi
case "$mode" in
  switch) info 'Готово' "Конфигурация применена. Перезагрузите ПК, когда будет удобно.\nЖурнал: $log_file" ;;
  build) info 'Сборка готова' "Система собрана без переключения. Применение:\nsudo nixos-rebuild switch --flake path:$target#current\nЖурнал: $log_file" ;;
  prepare) info 'Файлы готовы' "Подготовлены конфигурация и lock-файл. Сборка:\nsudo nixos-rebuild build --flake path:$target#current\nЖурнал: $log_file" ;;
esac
clear
printf 'Готово. Журнал: %s\n' "$log_file"
