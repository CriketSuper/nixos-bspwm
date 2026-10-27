#!/usr/bin/env bash
# Install on the TARGET PC. No partitioning, passwords or private files are copied.
set -euo pipefail
umask 022
export LC_ALL=C LANGUAGE=C
profile=universal
username=${SUDO_USER:-}
host_name=''
mode=build
target=/etc/nixos
backup_root=/var/backups/nixos-bspwm
ssh_key=''
ssh_mode=off
replace=false
settings_json=''
state_version=''
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source_dir=$(cd -- "$script_dir/.." && pwd)
usage() {
  cat <<'HELP'
Usage: sudo bash scripts/install.sh [options]
  --profile NAME    universal (default) or huawei-matebook-d16
  --user NAME       Existing normal user on THIS PC; password stays in place
  --hostname NAME   Hostname (default: this PC's hostname)
  --mode MODE       prepare, build (default), or switch
  --target DIR      Default: /etc/nixos
  --backup-root DIR Default: /var/backups/nixos-bspwm (local, root-only)
  --state-version YY.MM  Original installation version, if not detected
  --ssh-mode MODE   off (default), password, or key
  --ssh-key FILE    Explicitly add a public key (requires --ssh-mode key)
  --settings-json FILE  Wizard choices
  --replace        Migrate an existing desktop deployment after backing it up
  --help           Show help
Run from a clean, committed Git checkout on installed NixOS 26.05, x86_64/UEFI.
Only tracked repository files and THIS PC's hardware config are deployed.
Old private.nix, keys, vendor files and local settings are NOT imported.
Old files remain in a local root-only backup for rollback.
HELP
}
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
need_value() { [ "$#" -ge 2 ] && [ -n "$2" ] || die "Missing value for $1"; }
while [ "$#" -gt 0 ]; do
  case "$1" in
    --profile) need_value "$@"; profile=$2; shift 2 ;;
    --user) need_value "$@"; username=$2; shift 2 ;;
    --hostname) need_value "$@"; host_name=$2; shift 2 ;;
    --mode) need_value "$@"; mode=$2; shift 2 ;;
    --target) need_value "$@"; target=$2; shift 2 ;;
    --backup-root) need_value "$@"; backup_root=$2; shift 2 ;;
    --state-version) need_value "$@"; state_version=$2; shift 2 ;;
    --ssh-mode) need_value "$@"; ssh_mode=$2; shift 2 ;;
    --ssh-key) need_value "$@"; ssh_key=$2; shift 2 ;;
    --settings-json) need_value "$@"; settings_json=$2; shift 2 ;;
    --replace) replace=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done
[ "$(id -u)" -eq 0 ] || die 'Run with sudo.'
[ -e /etc/NIXOS ] || die 'An installed NixOS is required.'
[ "$(uname -m)" = x86_64 ] || die 'Only x86_64 Intel/AMD is supported.'
[ -d /sys/firmware/efi ] || die 'For BIOS use the manual installation instructions.'
case "$mode" in prepare|build|switch) ;; *) die 'Invalid mode.' ;; esac
case "$profile" in universal|huawei-matebook-d16) ;; *) die 'Unknown profile.' ;; esac
case "$ssh_mode" in off|password|key) ;; *) die 'Invalid SSH mode.' ;; esac
for path in "$target" "$backup_root"; do
  [[ "$path" =~ ^/[a-zA-Z0-9_./-]+$ ]] || die 'Use absolute paths without spaces.'
  [ "$(realpath -m -- "$path")" != / ] || die 'Path cannot be /.'
done
[ ! -L "$target" ] || die 'The deployment must not be a symlink.'
target=$(realpath -m -- "$target")
backup_root=$(realpath -m -- "$backup_root")
case "$backup_root/" in "$target/"*) die 'Backups must be outside the deployment.' ;; esac
if [ -z "$username" ] || [ "$username" = root ]; then username=$(getent passwd 1000 | cut -d : -f 1); fi
[[ "$username" =~ ^[a-z_][a-z0-9_-]*$ ]] || die 'Specify a valid --user.'
getent passwd "$username" >/dev/null || die "Create a normal user first: $username"
uid=$(id -u "$username")
[ "$uid" -ge 1000 ] || die 'Select a normal user.'
home_dir=$(getent passwd "$username" | cut -d : -f 6)
[[ "$home_dir" =~ ^/[a-zA-Z0-9_./-]+$ ]] || die 'Unsupported home path.'
host_name=${host_name:-$(hostname)}
[[ "$host_name" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*$ ]] || die 'Invalid hostname.'
if [ "$profile" = huawei-matebook-d16 ]; then
  grep -q AuthenticAMD /proc/cpuinfo || die 'This Huawei profile requires AMD.'
fi
for command in git nix-instantiate nixos-generate-config python3; do
  command -v "$command" >/dev/null || die "Missing command: $command"
done
[ -f "$source_dir/sources.nix" ] || die 'Run from a complete checkout.'
[ -z "$(git -c safe.directory="$source_dir" -C "$source_dir" status --porcelain --untracked-files=normal)" ] || die 'Commit/save source changes before deploying. Local configuration.nix and hardware files are ignored by Git.'
if [ -e "$target/flake.nix" ] || [ -d "$target/modules" ] || [ -e "$target/bspwm-repo" ]; then
  "$replace" || die 'An earlier desktop deployment exists. Review it, then use --replace.'
fi
settings_options=()
if [ -n "$settings_json" ]; then settings_options=(--options "$settings_json"); fi
python3 "$script_dir/render-settings.py" --validate-only "${settings_options[@]}"
if [ -z "$state_version" ]; then
  state_version=$(python3 "$script_dir/render-settings.py" --detect-state "$target") || die 'Specify the ORIGINAL --state-version YY.MM.'
fi
[[ "$state_version" =~ ^[0-9]{2}\.[0-9]{2}$ ]] || die 'Invalid stateVersion.'
if [ "$mode" = switch ] && [ "$ssh_mode" = key ] && [ -z "$ssh_key" ]; then
  die 'Key authentication needs --ssh-key before automatic switch. Use --mode build to edit authorizedKeys first.'
fi
if [ -n "$ssh_key" ]; then
  [ "$ssh_mode" = key ] || die '--ssh-key requires --ssh-mode key.'
  if [ ! -f "$ssh_key" ] || grep -q 'PRIVATE KEY' "$ssh_key"; then die 'Only a public SSH key is accepted.'; fi
  ssh-keygen -lf "$ssh_key" >/dev/null || die 'Invalid public SSH key.'
fi
mkdir -p -- "$(dirname -- "$target")"
stage=$(mktemp -d "${target}.stage.XXXXXX")
trap 'rm -rf -- "$stage"' EXIT
# A clean clone excludes ignored private files, runtime configs and credentials.
git -c safe.directory="$source_dir" clone --quiet --no-local -- "$source_dir" "$stage/repo"
git -C "$stage/repo" remote set-url origin https://github.com/CriketSuper/nixos-bspwm.git
hardware="$target/hardware-configuration.nix"
if [ -f "$target/flake.nix" ] && [ -f "$target/local/hardware-configuration.nix" ]; then hardware="$target/local/hardware-configuration.nix"; fi
if [ -f "$hardware" ]; then
  cp -L -- "$hardware" "$stage/repo/hardware-configuration.nix"
else
  nixos-generate-config --show-hardware-config > "$stage/repo/hardware-configuration.nix"
fi
python3 "$script_dir/render-settings.py" \
  --output "$stage/repo/configuration.nix" --profile "$profile" \
  --user "$username" --uid "$uid" --home "$home_dir" --hostname "$host_name" \
  --state-version "$state_version" --ssh-mode "$ssh_mode" --ssh-key "$ssh_key" "${settings_options[@]}"
chmod 644 "$stage/repo/configuration.nix" "$stage/repo/hardware-configuration.nix"
# Check syntax before moving the old directory. No old Nix expressions are run.
nix-instantiate --parse "$stage/repo/configuration.nix" >/dev/null
nix-instantiate --parse "$stage/repo/hardware-configuration.nix" >/dev/null
backup="$backup_root/$(date +%Y%m%d-%H%M%S)-$$"
install -d -m 700 "$backup_root" "$backup"
readlink -f /run/current-system > "$backup/system-path.txt"
if [ "$target" = /etc/nixos ]; then
  install -d /nix/var/nix/gcroots
  ln -s "$(readlink -f /run/current-system)" "/nix/var/nix/gcroots/bspwm-before-$(basename "$backup")"
fi
if [ -d "$target" ]; then mv -- "$target" "$backup/config-before"; fi
if ! mv -- "$stage/repo" "$target"; then
  [ ! -d "$backup/config-before" ] || mv -- "$backup/config-before" "$target"
  die 'Deployment failed; original directory restored.'
fi
printf 'Profile: %s\nLocal backup: %s\nConfiguration: %s/configuration.nix\n' "$profile" "$backup" "$target"
printf 'Private files were not imported. This PC retains its existing account password.\n'
case "$mode" in
  prepare) printf 'Prepared. Next: sudo nixos-rebuild build -I nixos-config=%s/configuration.nix\n' "$target" ;;
  build|switch)
    nixos-rebuild build -I "nixos-config=$target/configuration.nix"
    if [ "$mode" = switch ]; then
      nixos-rebuild switch -I "nixos-config=$target/configuration.nix"
      printf 'Activated. Reboot when convenient.\n'
    else printf 'Build succeeded. Apply: sudo nixos-rebuild switch\n'
    fi ;;
esac
