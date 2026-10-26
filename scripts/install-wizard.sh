#!/usr/bin/env bash
set -euo pipefail
umask 077
# Keep prompts, dialog buttons and subprocess messages readable on live consoles.
export LC_ALL=C LANGUAGE=C
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
[ -e /etc/NIXOS ] || { printf 'An existing NixOS installation is required.\n' >&2; exit 1; }
[ "$(uname -m)" = x86_64 ] && [ -d /sys/firmware/efi ] || {
  printf 'This wizard requires x86_64 with UEFI. See docs/installation.md for other setups.\n' >&2
  exit 1
}
[ -t 0 ] && [ -t 1 ] || { printf 'The wizard needs an interactive terminal. For SSH, use ssh -t.\n' >&2; exit 1; }
missing=false
for command in dialog git python3; do
  command -v "$command" >/dev/null || missing=true
done
if "$missing"; then
  [ "${BSPWM_WIZARD_DEPS_ATTEMPTED:-0}" != 1 ] || { printf 'Could not load the wizard dependencies.\n' >&2; exit 1; }
  export BSPWM_WIZARD_ENTRY="$entry" BSPWM_WIZARD_TARGET="$target" BSPWM_WIZARD_DEPS_ATTEMPTED=1
  # shellcheck disable=SC2016 # Expanded by the shell inside nix-shell.
  exec nix-shell -p git python3 dialog --run 'exec bash "$BSPWM_WIZARD_ENTRY" --target "$BSPWM_WIZARD_TARGET"'
fi
ui() { dialog --ascii-lines --no-shadow --backtitle 'NixOS BSPWM - Setup wizard' "$@"; }
cancel() { clear; printf 'Setup cancelled before starting the build.\n'; exit 0; }
info() { ui --title "$1" --msgbox "$2" 0 0; }
input() {
  local value
  value=$(ui --stdout --title "$1" --inputbox "$2" 0 0 "$3") || return 130
  printf '%s' "$value"
}
port_input() {
  local value
  while true; do
    value=$(input "$1" 'TCP port (1-65535):' "$2") || return 130
    if [[ "$value" =~ ^[0-9]{1,5}$ ]] && ((10#$value >= 1 && 10#$value <= 65535)); then printf '%s' "$((10#$value))"; return; fi
    info 'Invalid port' 'Enter a number from 1 to 65535.'
  done
}
[[ "$target" =~ ^/[a-zA-Z0-9_./-]+$ ]] || { info 'Invalid path' 'Use an absolute path without spaces.'; exit 1; }
target=$(realpath -m -- "$target")
[ "$target" != / ] || { info 'Invalid path' 'The filesystem root cannot be the target.'; exit 1; }
ui --title 'BSPWM setup' --yesno 'This wizard configures the desktop on an existing NixOS installation. Disk partitions will not be formatted. Your configuration will be backed up before any changes.\n\nContinue?' 0 0 || cancel
replace_args=()
existing=false
if [ -e "$target/flake.nix" ] || [ -e "$target/bspwm-repo" ]; then
  ui --defaultno --title 'Existing configuration' --yesno 'This directory already contains a flake or Git deployment. Replace it?\n\nExisting local/ files will be kept, including their user, application and key settings.' 0 0 || cancel
  replace_args=(--replace)
  existing=true
fi
profile_default=universal
if [ -f "$target/flake.nix" ]; then
  previous_profile=$(sed -nE 's/^[[:space:]]*profile = "([a-z0-9-]+)";.*/\1/p' "$target/flake.nix" | head -n 1)
  case "$previous_profile" in universal|huawei-matebook-d16) profile_default=$previous_profile ;; esac
fi
profile=$(ui --stdout --default-item "$profile_default" --title 'Hardware profile' --menu 'Select your hardware profile:' 0 0 2 \
  universal 'Other Intel/AMD PC' \
  huawei-matebook-d16 'Huawei MateBook D16 AMD, BOM-WXX9') || cancel
if [ "$profile" = huawei-matebook-d16 ] && ! grep -q AuthenticAMD /proc/cpuinfo; then
  info 'Unsupported profile' 'Use universal for Intel MateBooks and other computers.'
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
    username=$(input 'User account' 'Existing normal user name. The current password will be preserved:' "$username") || cancel
    if [[ "$username" =~ ^[a-z_][a-z0-9_-]*$ ]] && id "$username" >/dev/null 2>&1 && [ "$(id -u "$username")" -ge 1000 ]; then break; fi
    info 'User not found' 'Create a normal NixOS user first, or enter an existing user name.'
  done
  while true; do
    hostname=$(input 'Computer name' 'Hostname (ASCII letters, digits and hyphens):' "$hostname") || cancel
    [[ "$hostname" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*$ ]] && break
    info 'Invalid name' 'Use ASCII letters, digits and hyphens.'
  done
  timezone=$(timedatectl show -p Timezone --value 2>/dev/null || true)
  timezone=${timezone:-Asia/Yekaterinburg}
  while true; do
    timezone=$(input 'Time zone' 'For example: Asia/Yekaterinburg, Europe/Moscow or Etc/UTC:' "$timezone") || cancel
    if timedatectl list-timezones | grep -Fx -- "$timezone" >/dev/null; then break; fi
    info 'Time zone not found' 'Enter a name listed by timedatectl list-timezones.'
  done
  state_version=""
  if [ -f /etc/nixos/configuration.nix ]; then
    state_version=$(sed -nE 's/^[[:space:]]*system\.stateVersion[[:space:]]*=[[:space:]]*"([0-9]{2}\.[0-9]{2})";.*/\1/p' /etc/nixos/configuration.nix | head -n 1)
  fi
  state_version=${state_version:-$(nixos-version | cut -d . -f 1,2)}
  while true; do
    state_version=$(input 'Data compatibility' 'system.stateVersion is the initial installation version. Keep the original value for an existing system:' "$state_version") || cancel
    [[ "$state_version" =~ ^[0-9]{2}\.[0-9]{2}$ ]] && break
    info 'Invalid version' 'Expected format: 26.05.'
  done
  features=$(ui --stdout --separate-output --title 'Applications and services' --checklist 'Space: select; Enter: continue. The core desktop and everyday applications are always installed.' 0 0 5 \
    development 'Editors, compilers and development tools' on \
    virtualisation 'Docker and QEMU (without VirtualBox)' on \
    vpn 'Hiddify, v2rayA/Xray, AmneziaVPN' on \
    rdp 'Remote desktop with xrdp' on \
    ssh 'SSH with your public key' off) || cancel
  selected() { grep -Fqx -- "$1" <<<"$features"; }
  rdp_port=3389
  ssh_port=5555
  if selected rdp; then rdp_port=$(port_input 'RDP port' 3389) || cancel; fi
  if selected ssh; then
    ssh_port=$(port_input 'SSH port' 5555) || cancel
    user_home=$(getent passwd "$username" | cut -d : -f 6)
    key_path="$user_home/.ssh/id_ed25519.pub"
    while true; do
      key_path=$(input 'SSH public key' 'Full path to a .pub file. Do not provide a private key:' "$key_path") || cancel
      if [ -f "$key_path" ] && ! grep -q 'PRIVATE KEY' "$key_path" && ssh-keygen -lf "$key_path" >/dev/null 2>&1; then break; fi
      info 'Invalid key' 'Select an existing public key, such as id_ed25519.pub.'
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
  selected development && component_names+=('Development')
  selected virtualisation && component_names+=('Docker/QEMU')
  selected vpn && component_names+=('VPN clients')
  if selected rdp; then component_names+=("RDP:$rdp_port"); fi
  if selected ssh; then component_names+=("SSH:$ssh_port"); fi
  component_summary='Core desktop only'
  if [ "${#component_names[@]}" -gt 0 ]; then
    component_summary=$(IFS=', '; printf '%s' "${component_names[*]}")
  fi
  summary="Profile: $profile\nUser: $username\nComputer: $hostname\nTime zone: $timezone\nstateVersion: $state_version\nComponents: $component_summary\nConfiguration directory: $target"
  if selected ssh; then summary="$summary\nSSH public key: $key_path"; fi
else
  summary="Profile: $profile\nConfiguration directory: $target\nExisting local/ files and passwords will be kept. User and service settings will not be changed."
fi
args+=(--user "$username" --hostname "$hostname" "${replace_args[@]}")
mode=$(ui --stdout --title 'Review and install' --default-item build --menu "$summary\n\nSelect an action:" 0 0 3 \
  build 'Build without activating (recommended)' \
  switch 'Build and activate the configuration' \
  prepare 'Prepare configuration files only') || cancel
log_dir=/var/log/nixos-bspwm
install -d -m 700 "$log_dir"
log_file="$log_dir/install-$(date +%Y%m%d-%H%M%S)-$$.log"
set +e
bash "$repo_dir/scripts/install.sh" "${args[@]}" --mode "$mode" 2>&1 | tee "$log_file" | ui --title 'BSPWM setup' --programbox 0 0
pipeline_status=("${PIPESTATUS[@]}")
set -e
if [ "${pipeline_status[0]}" -ne 0 ]; then
  info 'Setup did not finish' "Details: $log_file\nBackups: /var/backups/nixos-bspwm/\nA failed build does not activate the new system."
  exit 1
fi
case "$mode" in
  switch) info 'Done' "Configuration activated. Reboot when convenient.\nLog: $log_file" ;;
  build) info 'Build complete' "Built without activating. Apply with:\nsudo env NIX_CONFIG='experimental-features = nix-command flakes' nixos-rebuild switch --flake path:$target#current\nLog: $log_file" ;;
  prepare) info 'Files ready' "Configuration and lock file prepared. Build with:\nsudo env NIX_CONFIG='experimental-features = nix-command flakes' nixos-rebuild build --flake path:$target#current\nLog: $log_file" ;;
esac
clear
printf 'Done. Log: %s\n' "$log_file"
